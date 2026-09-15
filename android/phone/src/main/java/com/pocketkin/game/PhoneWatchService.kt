package com.pocketkin.game

import android.content.Context
import com.google.android.gms.wearable.*
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.io.File

class PhoneWatchService : WearableListenerService() {
    companion object {
        private val scope=CoroutineScope(SupervisorJob()+Dispatchers.IO)
        private val pending=java.util.concurrent.ConcurrentHashMap<String,String>()
        fun acknowledge(context:Context,ack:JSONObject) {
            val node=pending.remove(ack.optString("id")) ?: return
            scope.launch { runCatching { Wearable.getMessageClient(context).sendMessage(node,"/kin/ack",ack.toString().toByteArray()).await() } }
        }
    }
    override fun onCreate() {
        super.onCreate()
        PhoneSyncServer.start(this)
    }
    override fun onMessageReceived(event:MessageEvent) {
        scope.launch {
            PhoneSyncServer.start(this@PhoneWatchService)
            val prefs=getSharedPreferences("kin_native",0)
            if(event.path=="/kin/ping") {
                val snapshot=JSONObject(prefs.getString("snapshot","{}") ?: "{}")
                snapshot.put("phone_ip", PhoneSyncServer.getLocalIpAddress(this@PhoneWatchService))
                snapshot.put("server_port", PhoneSyncServer.PORT)
                runCatching { Wearable.getMessageClient(this@PhoneWatchService).sendMessage(event.sourceNodeId,"/kin/state",snapshot.toString().toByteArray()).await() }
                return@launch
            }
            if(event.path=="/kin/sync_health") {
                val data=runCatching { JSONObject(String(event.data)) }.getOrNull() ?: return@launch
                val steps=data.optInt("steps", 0)
                prefs.edit()
                    .putInt("watch_steps", steps)
                    .putInt("watch_heart_rate", data.optInt("heart_rate", 0))
                    .putInt("watch_hydration", data.optInt("hydration", 0))
                    .putInt("watch_active_min", data.optInt("active_minutes", 0))
                    .putLong("watch_health_synced", System.currentTimeMillis())
                    .apply()
                val plugin=KinPlugin.current.get()
                if(plugin!=null && !plugin.isPaused()) { plugin.reply("watch_health", data) }
                val path=prefs.getString("save_path","") ?: ""
                val file=File(path)
                if(steps > 0 && file.isFile) synchronized(PhoneWatchService::class.java) {
                    runCatching {
                        val save=JSONObject(file.readText())
                        val walking=save.optJSONObject("walking") ?: JSONObject()
                        if(steps > walking.optInt("steps", 0)) {
                            walking.put("steps", steps)
                            walking.put("updated", System.currentTimeMillis() / 1000.0)
                            walking.put("source", "watch_bluetooth")
                            save.put("walking", walking)
                            file.writeText(save.toString())
                            prefs.edit().putBoolean("external_save_changed", true).apply()
                            KinWidget.update(this@PhoneWatchService)
                        }
                    }
                }
                val ack=JSONObject().put("ok", true).put("message", "Watch health synchronized via Bluetooth")
                runCatching { Wearable.getMessageClient(this@PhoneWatchService).sendMessage(event.sourceNodeId, "/kin/ack", ack.toString().toByteArray()).await() }
                return@launch
            }
            if(event.path!="/kin/action") return@launch
            val input=runCatching { JSONObject(String(event.data)) }.getOrNull() ?: return@launch
            val id=input.optString("id")
            if(id.isBlank() || id.length>100) return@launch
            pending[id]=event.sourceNodeId
            val plugin=KinPlugin.current.get()
            if(plugin!=null && !plugin.isPaused()) { plugin.reply("watch_action",input); return@launch }
            val path=prefs.getString("save_path","") ?: ""
            val file=File(path)
            val valid=file.canonicalPath.startsWith(filesDir.canonicalPath+File.separator) && file.isFile
            val ack=JSONObject().put("id",id).put("ok",false)
            if(valid) synchronized(PhoneWatchService::class.java) {
                runCatching {
                    val save=JSONObject(file.readText())
                    val outcome=NativeCare.apply(save,input,System.currentTimeMillis()/1000.0)
                    ack.put("ok",outcome).put("revision",save.optLong("revision"))
                    if(outcome) {
                        val temporary=File(path+".watch.tmp")
                        temporary.writeText(save.toString())
                        file.copyTo(File(path+".bak"),overwrite=true)
                        check(temporary.renameTo(file))
                        prefs.edit().putBoolean("external_save_changed",true).apply()
                        val snapshot=JSONObject(prefs.getString("snapshot","{}") ?: "{}")
                        snapshot.put("pet",save.getJSONObject("pet")).put("revision",save.optLong("revision"))
                        prefs.edit().putString("snapshot",snapshot.toString()).apply()
                        KinWidget.update(this@PhoneWatchService)
                        CareScheduler.schedule(this@PhoneWatchService)
                        val data=PutDataMapRequest.create("/kin/state")
                        data.dataMap.putString("json",snapshot.toString());data.dataMap.putLong("synced",System.currentTimeMillis())
                        Wearable.getDataClient(this@PhoneWatchService).putDataItem(data.asPutDataRequest().setUrgent())
                    }
                }
            }
            acknowledge(this@PhoneWatchService,ack)
        }
    }
}

object NativeCare {
    fun apply(save:JSONObject,input:JSONObject,now:Double):Boolean {
        val receipts=save.optJSONObject("watch_receipts") ?: JSONObject()
        val id=input.optString("id")
        if(receipts.has(id)) return receipts.optBoolean(id)
        val pet=save.optJSONObject("pet") ?: return false
        if(pet.optString("id")!=input.optString("pet_id") || save.optLong("revision")!=input.optLong("revision",-1))return false
        val action=input.optString("action")
        if(action !in setOf("feed","love","clean","sleep","watch_play"))return false
        val last=pet.optJSONObject("last_actions") ?: JSONObject()
        if(now-last.optDouble(action,0.0)<3)return false
        val settings=save.optJSONObject("settings") ?: JSONObject()
        val then=pet.optDouble("updated",now)
        val elapsed=(now-then).coerceAtLeast(0.0)
        val hours=awake(then,now,settings.optInt("sleep_hour",22),settings.optInt("wake_hour",7),settings.optInt("utc_offset",0))/3600.0
        val healthy=((pet.optDouble("hunger",85.0)-20)/8).coerceIn(0.0,hours)
        val safe=maxOf(0.0,minOf((pet.optDouble("hunger",85.0)-10)/8,(pet.optDouble("cleanliness",95.0)-10)/4))
        val neglected=maxOf(0.0,hours-safe)
        pet.put("neglect_hours",if(neglected>0)pet.optDouble("neglect_hours",0.0)+neglected else 0.0)
        pet.put("care_age",pet.optDouble("care_age",0.0)+minOf(elapsed,healthy*3600+(elapsed-hours*3600)))
        for((key,rate) in listOf("hunger" to 8.0,"happiness" to 5.0,"cleanliness" to 4.0))pet.put(key,(pet.optDouble(key,80.0)-hours*rate).coerceIn(0.0,100.0))
        val energy=pet.optDouble("energy",80.0)+if(pet.optBoolean("sleeping"))elapsed/3600*18 else -hours*6+(elapsed/3600-hours)*15
        pet.put("energy",energy.coerceIn(0.0,100.0)).put("updated",maxOf(then,now))
        if(pet.optDouble("neglect_hours",0.0)>=4)pet.put("ill",true)
        pet.put("stage",if(pet.optDouble("care_age")>=604800)"adult" else if(pet.optDouble("care_age")>=172800)"juvenile" else "baby")
        when(action){
            "feed"->pet.put("hunger",minOf(100.0,pet.optDouble("hunger")+28))
            "love"->pet.put("happiness",minOf(100.0,pet.optDouble("happiness")+20))
            "clean"->pet.put("cleanliness",minOf(100.0,pet.optDouble("cleanliness")+40))
            "sleep"->pet.put("sleeping",!pet.optBoolean("sleeping"))
            "watch_play"->{
                if(input.optInt("duration")<20 || now-last.optDouble("watch_play",0.0)<20)return false
                val hits=input.optInt("hits").coerceIn(0,14)
                pet.put("happiness",minOf(100.0,pet.optDouble("happiness")+12))
                save.put("coins",save.optInt("coins")+minOf(30,5+hits))
            }
        }
        pet.put("bond",pet.optInt("bond")+1)
        save.put("lifetime_bond",save.optInt("lifetime_bond")+1)
        last.put(action,now);pet.put("last_actions",last)
        val daily=save.optJSONObject("daily") ?: JSONObject()
        val date=java.time.LocalDate.now().toString()
        val tasks=daily.optJSONObject(date) ?: JSONObject()
        val task=if(action=="watch_play")"play" else "care"
        tasks.put(task,tasks.optInt(task)+1);daily.put(date,tasks);save.put("daily",daily)
        receipts.put(id,true)
        while(receipts.length()>100)receipts.remove(receipts.keys().next())
        save.put("watch_receipts",receipts).put("revision",save.optLong("revision")+1)
        return true
    }
    fun awake(start:Double,end:Double,sleep:Int,wake:Int,offset:Int):Double {
        if(end<=start)return 0.0
        val days=((end-start)/86400).toInt()
        var total=days*(24-Math.floorMod(wake-sleep,24))*3600.0
        var cursor=start+days*86400.0
        while(cursor<end){
            val local=cursor+offset
            val hour=Math.floorMod(kotlin.math.floor(local/3600).toInt(),24)
            val next=minOf(end,cursor+3600-((local%3600+3600)%3600))
            if(!CareScheduler.quiet(hour,sleep,wake))total+=next-cursor
            cursor=next
        }
        return total
    }
}
