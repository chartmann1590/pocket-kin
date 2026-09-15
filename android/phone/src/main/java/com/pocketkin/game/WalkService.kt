package com.pocketkin.game

import android.app.*
import android.content.Intent
import android.hardware.*
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.time.LocalDate

class WalkService : Service(), SensorEventListener {
    private lateinit var manager: SensorManager
    private var baseline = -1f
    private var day = LocalDate.now().toString()
    override fun onCreate() {
        super.onCreate()
        val notifications = getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(NotificationChannel("walking","Walking together",NotificationManager.IMPORTANCE_LOW))
        val stop = PendingIntent.getService(this,10,Intent(this,WalkService::class.java).setAction("stop"),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        startForeground(10,NotificationCompat.Builder(this,"walking").setSmallIcon(R.drawable.kin_launcher).setContentTitle("Walking with your little friend").setContentText("Counting this phone's steps. Tap Stop when you're done.").setOngoing(true).addAction(0,"Stop",stop).build())
        manager = getSystemService(SENSOR_SERVICE) as SensorManager
        val sensor = manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null || !manager.registerListener(this,sensor,SensorManager.SENSOR_DELAY_NORMAL)) stopSelf()
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int { if (intent?.action=="stop") stopSelf(); return START_NOT_STICKY }
    override fun onSensorChanged(event: SensorEvent) {
        val prefs = getSharedPreferences("kin_native",0)
        val today = LocalDate.now().toString()
        val count = event.values[0]
        if (today != day) { day=today; baseline=count }
        if (prefs.getString("source:$day","") == "health-connect") { stopSelf(); return }
        if (baseline >= 0 && count >= baseline) {
            val delta = (count-baseline).toLong().coerceAtLeast(0)
            prefs.edit().putString("source:$day","sensor").putLong("steps:$day",prefs.getLong("steps:$day",0)+delta).apply()
        }
        baseline=count
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onDestroy() { if (::manager.isInitialized) manager.unregisterListener(this); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}
