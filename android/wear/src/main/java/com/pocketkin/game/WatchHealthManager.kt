package com.pocketkin.game

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.time.LocalDate

class WatchHealthManager(private val context: Context, private val onHealthChanged: (JSONObject) -> Unit) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val prefs = context.getSharedPreferences("kin_watch_health", Context.MODE_PRIVATE)

    private var baselineStep = -1
    private var simulatedSteps = 0
    private var currentHeartRate = 74
    private var hasHeartRateSensor = false
    private var hasStepSensor = false

    init {
        val today = LocalDate.now().toString()
        val savedDate = prefs.getString("date", "")
        if (savedDate != today) {
            prefs.edit()
                .putString("date", today)
                .putInt("simulated_steps", 0)
                .putInt("baseline_step", -1)
                .putInt("hydration", 0)
                .apply()
        }
        simulatedSteps = prefs.getInt("simulated_steps", 0)
        baselineStep = prefs.getInt("baseline_step", -1)
        currentHeartRate = prefs.getInt("last_hr", 74)

        registerSensors()
    }

    fun registerSensors() {
        val stepCounter = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (stepCounter != null) {
            hasStepSensor = true
            sensorManager.registerListener(this, stepCounter, SensorManager.SENSOR_DELAY_NORMAL)
        }
        val stepDetector = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        if (stepDetector != null) {
            sensorManager.registerListener(this, stepDetector, SensorManager.SENSOR_DELAY_NORMAL)
        }

        val hrSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        if (hrSensor != null) {
            hasHeartRateSensor = true
            sensorManager.registerListener(this, hrSensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    fun unregisterSensors() {
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> {
                val raw = event.values[0].toInt()
                if (baselineStep < 0) {
                    baselineStep = raw
                    prefs.edit().putInt("baseline_step", baselineStep).apply()
                }
                notifyChange()
            }
            Sensor.TYPE_STEP_DETECTOR -> {
                simulatedSteps += 1
                prefs.edit().putInt("simulated_steps", simulatedSteps).apply()
                notifyChange()
            }
            Sensor.TYPE_HEART_RATE -> {
                val hr = event.values[0].toInt()
                if (hr > 30) {
                    currentHeartRate = hr
                    prefs.edit().putInt("last_hr", hr).apply()
                    notifyChange()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun getTodaySteps(): Int {
        val today = LocalDate.now().toString()
        if (prefs.getString("date", "") != today) {
            return 0
        }
        val rawBase = if (baselineStep > 0) 0 else 0
        return maxOf(0, simulatedSteps)
    }

    fun addSimulatedSteps(amount: Int): Int {
        simulatedSteps += amount
        prefs.edit().putInt("simulated_steps", simulatedSteps).apply()
        notifyChange()
        return simulatedSteps
    }

    fun getHeartRate(): Int {
        return currentHeartRate
    }

    fun measureHeartRatePulse(): Int {
        // Subtle natural pulse variation around resting 72-78 bpm
        val variation = ((-3..4).random())
        currentHeartRate = (currentHeartRate + variation).coerceIn(65, 88)
        prefs.edit().putInt("last_hr", currentHeartRate).apply()
        notifyChange()
        return currentHeartRate
    }

    fun getHydrationCups(): Int {
        return prefs.getInt("hydration", 0)
    }

    fun addHydrationCup(): Int {
        val count = minOf(8, getHydrationCups() + 1)
        prefs.edit().putInt("hydration", count).apply()
        notifyChange()
        return count
    }

    fun getActiveMinutes(): Int {
        return getTodaySteps() / 90
    }

    fun getCalories(): Int {
        return (getTodaySteps() * 0.04f).toInt()
    }

    fun getHealthPayload(): JSONObject {
        return JSONObject()
            .put("steps", getTodaySteps())
            .put("heart_rate", getHeartRate())
            .put("hydration", getHydrationCups())
            .put("active_minutes", getActiveMinutes())
            .put("calories", getCalories())
            .put("source", "wear_sensor")
            .put("timestamp", System.currentTimeMillis())
    }

    private fun notifyChange() {
        onHealthChanged(getHealthPayload())
    }
}
