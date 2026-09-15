package com.pocketkin.game

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.time.*

object CareScheduler {
    fun schedule(context: Context) {
        val prefs = context.getSharedPreferences("kin_native",0)
        val settings = JSONObject(prefs.getString("settings","{}") ?: "{}")
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (i in 0..2) alarms.cancel(pending(context,i))
        if (!settings.optBoolean("reminders")) return
        val start = settings.optInt("quiet_start",settings.optInt("sleep_hour",22))
        val end = settings.optInt("quiet_end",settings.optInt("wake_hour",7))
        val now = ZonedDateTime.now()
        var candidate = now.plusHours(4).withMinute(0).withSecond(0)
        for (i in 0..2) {
            while (quiet(candidate.hour,start,end)) candidate = candidate.plusHours(1)
            alarms.setWindow(AlarmManager.RTC_WAKEUP,candidate.toInstant().toEpochMilli(),3600000,pending(context,i))
            candidate=candidate.plusHours(5)
        }
    }
    fun quiet(hour: Int,start: Int,end: Int) = if (start>end) hour>=start || hour<end else hour>=start && hour<end
    private fun pending(context: Context,id: Int) = PendingIntent.getBroadcast(context,id,Intent(context,CareReceiver::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
}
class CareReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        val prefs=context.getSharedPreferences("kin_native",0)
        val settings=JSONObject(prefs.getString("settings","{}") ?: "{}")
        if (!settings.optBoolean("reminders")) return
        if (CareScheduler.quiet(LocalTime.now().hour,settings.optInt("quiet_start",22),settings.optInt("quiet_end",7))) return
        if (Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) return
        val key="reminders:"+LocalDate.now()
        if (prefs.getInt(key,0)>=3) return
        val manager=context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("care","Friendly pet reminders",NotificationManager.IMPORTANCE_DEFAULT))
        val open=PendingIntent.getActivity(context,0,Intent(context,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        manager.notify(20,NotificationCompat.Builder(context,"care").setSmallIcon(R.drawable.kin_launcher).setContentTitle("A little moment together?").setContentText("Your little friend would love some company.").setContentIntent(open).setAutoCancel(true).build())
        prefs.edit().putInt(key,prefs.getInt(key,0)+1).apply()
    }
}
class BootReceiver : BroadcastReceiver() { override fun onReceive(context: Context,intent: Intent) { CareScheduler.schedule(context) } }
