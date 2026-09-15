package com.pocketkin.game

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

class KinServices(private val activity: Activity, private val reply: (String, JSONObject) -> Unit) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    val prefs = activity.getSharedPreferences("kin_native", 0)
    var paused = false
    private val steps by lazy { StepsBridge(activity, scope, reply) }
    private val cloud by lazy { CloudBridge(activity, scope, reply) }
    private val ads by lazy { AdsBridge(activity, reply) }
    private val billing by lazy { BillingBridge(activity, scope, reply, cloud) }
    private var walkRequest = JSONObject()

    fun request(kind: String, input: JSONObject) {
        when (kind) {
            "insets" -> {
                val insets=androidx.core.view.ViewCompat.getRootWindowInsets(activity.window.decorView)?.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars() or androidx.core.view.WindowInsetsCompat.Type.displayCutout() or androidx.core.view.WindowInsetsCompat.Type.ime())
                if(insets!=null)reply("insets",JSONObject().put("top",insets.top).put("bottom",insets.bottom))
            }
            "screen" -> prefs.edit().putString("screen",input.optString("page")).apply()
            "fullscreen" -> {
                prefs.edit().putBoolean("fullscreen",input.optBoolean("enabled")).apply()
                val controller=androidx.core.view.WindowCompat.getInsetsController(activity.window,activity.window.decorView)
                controller.systemBarsBehavior=androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if(input.optBoolean("enabled"))controller.hide(androidx.core.view.WindowInsetsCompat.Type.systemBars()) else controller.show(androidx.core.view.WindowInsetsCompat.Type.systemBars())
                activity.window.decorView.postDelayed({request("insets",JSONObject())},250)
            }
            "pin_widget" -> {
                val manager=android.appwidget.AppWidgetManager.getInstance(activity)
                if(manager.isRequestPinAppWidgetSupported)manager.requestPinAppWidget(android.content.ComponentName(activity,KinWidget::class.java),null,null)
                else message(kind,"Long-press your home screen, choose Widgets, then Pocket Kin.")
            }
            "snapshot" -> {
                input.put("phone_ip", PhoneSyncServer.getLocalIpAddress(activity))
                input.put("server_port", PhoneSyncServer.PORT)
                val snapshotStr = input.toString()
                PhoneSyncServer.latestSnapshot = input
                prefs.edit().putString("snapshot", snapshotStr).apply()
                input.optString("save_path").takeIf { it.isNotBlank() }?.let { prefs.edit().putString("save_path", it).apply() }
                KinWidget.update(activity)
                openWidget()
                scope.launch(Dispatchers.IO) {
                    // 1. Wearable DataClient (Primary background sync)
                    runCatching {
                        val data = PutDataMapRequest.create("/kin/state")
                        data.dataMap.putString("json", snapshotStr)
                        data.dataMap.putLong("synced", System.currentTimeMillis())
                        Wearable.getDataClient(activity).putDataItem(data.asPutDataRequest().setUrgent()).await()
                    }
                    // 2. Wearable MessageClient (Instant push to all connected nodes)
                    runCatching {
                        val nodes = Wearable.getNodeClient(activity).connectedNodes.await()
                        val bytes = snapshotStr.toByteArray(java.nio.charset.StandardCharsets.UTF_8)
                        for (node in nodes) {
                            Wearable.getMessageClient(activity).sendMessage(node.id, "/kin/state", bytes).await()
                        }
                    }
                }
            }
            "get_watch_health" -> {
                val h = JSONObject()
                    .put("steps", prefs.getInt("watch_steps", 0))
                    .put("heart_rate", prefs.getInt("watch_heart_rate", 0))
                    .put("hydration", prefs.getInt("watch_hydration", 0))
                    .put("active_minutes", prefs.getInt("watch_active_min", 0))
                    .put("calories", prefs.getInt("watch_calories", 0))
                    .put("synced", prefs.getLong("watch_health_synced", 0L))
                reply("watch_health", h)
            }
            "steps" -> { walkRequest = input; steps.read(input.optLong("activated")) }
            "steps_permission" -> {
                walkRequest = input
                activity.startActivityForResult(PermissionController.createRequestPermissionResultContract().createIntent(activity, setOf(HealthPermission.getReadPermission(StepsRecord::class))), 701)
            }
            "start_walk" -> {
                walkRequest = input
                if (Build.VERSION.SDK_INT >= 29 && ActivityCompat.checkSelfPermission(activity, Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), 702)
                else startWalk()
            }
            "stop_walk" -> { activity.stopService(Intent(activity, WalkService::class.java)); steps.read(walkRequest.optLong("activated")); message(kind,"Walking session stopped.") }
            "reminders" -> {
                prefs.edit().putString("settings", input.toString()).apply()
                if (input.optBoolean("reminders") && Build.VERSION.SDK_INT >= 33 && ActivityCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS),703)
                CareScheduler.schedule(activity)
                message(kind, if (input.optBoolean("reminders")) "Reminders follow your quiet hours." else "Reminders turned off.")
            }
            "care_complete" -> { prefs.edit().putString("settings",input.toString()).apply(); CareScheduler.schedule(activity) }
            "sign_in" -> cloud.signIn()
            "cloud_save" -> cloud.save(input)
            "cloud_load" -> cloud.load()
            "delete_account" -> AlertDialog.Builder(activity).setTitle("Delete cloud account?").setMessage("This removes cloud saves and account data. Your on-device pet remains. Purchases can be restored with Google Play.").setNegativeButton("Cancel",null).setPositiveButton("Delete") { _,_ -> cloud.delete() }.show()
            "rewarded" -> ads.rewarded()
            "interstitial" -> ads.interstitial()
            "privacy" -> ads.privacy()
            "purchase" -> billing.purchase(input.optString("product"))
            "restore" -> billing.restore()
            "watch_status" -> scope.launch {
                val nodes = runCatching { Wearable.getNodeClient(activity).connectedNodes.await() }.getOrDefault(emptyList())
                message(kind, if (nodes.isEmpty()) "Install Pocket Kin on your paired Wear OS watch, then open both apps." else "Connected to ${nodes.joinToString { it.displayName }}.")
            }
            "watch_ack" -> PhoneWatchService.acknowledge(activity,input)
            "age_setup" -> ads.configureAge()
        }
    }
    private fun startWalk() {
        val today = java.time.LocalDate.now().toString()
        if (prefs.getString("source:$today","") == "health-connect") { message("steps","Today's steps already use Health Connect. Keep using that source today to avoid counting steps twice."); return }
        val sensor = (activity.getSystemService(Activity.SENSOR_SERVICE) as android.hardware.SensorManager).getDefaultSensor(android.hardware.Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) { message("steps", "This phone has no step counter. Connect a Health Connect source instead."); return }
        prefs.edit().putBoolean("sensor_mode",true).apply()
        activity.startForegroundService(Intent(activity,WalkService::class.java))
        message("steps", "Phone walking session started. Carry your phone with you.")
    }
    fun openWidget() {
        val page=activity.intent?.getStringExtra("kin_widget_page") ?: return
        activity.intent.removeExtra("kin_widget_page")
        reply("widget_open",JSONObject().put("page",page))
    }
    fun resume() {
        paused = false
        openWidget()
        if (prefs.getBoolean("external_save_changed",false)) {
        val file = java.io.File(prefs.getString("save_path","") ?: "")
        if (file.isFile) runCatching { reply("external_save", JSONObject().put("save",JSONObject(file.readText())).put("ok",true)) }
        prefs.edit().putBoolean("external_save_changed",false).apply()
    } }
    fun activityResult(code: Int, result: Int, data: Intent?) {
        if (code == 701) steps.read(walkRequest.optLong("activated"),false)
        if (code == 704) cloud.signInResult(data)
    }
    fun permissionResult(code: Int, grants: IntArray) {
        if (code == 702 && grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) startWalk()
        if (code == 703) CareScheduler.schedule(activity)
    }
    fun close() { scope.cancel() }
    private fun message(kind: String, text: String) = reply(kind, JSONObject().put("message",text))
}
