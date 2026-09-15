package com.pocketkin.game

import android.app.Activity
import android.app.AlertDialog
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.*

class StepsBridge(private val activity: Activity, private val scope: CoroutineScope, private val reply: (String,JSONObject)->Unit) {
    fun read(activatedSeconds: Long, requestPermission: Boolean = true) = scope.launch {
        val prefs = activity.getSharedPreferences("kin_native",0)
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        val activation = Instant.ofEpochSecond(activatedSeconds.takeIf { it > 0 } ?: Instant.now().epochSecond)
        val available = HealthConnectClient.getSdkStatus(activity) == HealthConnectClient.SDK_AVAILABLE
        val client = if (available) HealthConnectClient.getOrCreate(activity) else null
        val allowed = client?.permissionController?.getGrantedPermissions()?.contains(HealthPermission.getReadPermission(StepsRecord::class)) == true
        if (client != null && !allowed && prefs.getString("source:$today","") != "sensor") {
            reply("steps",JSONObject().put("ok",false).put("permission_required",requestPermission).put("message","Step access is optional. You can enable it later in Health Connect."))
            return@launch
        }
        for (date in listOf(today.minusDays(1),today)) {
            val source = prefs.getString("source:$date","") ?: ""
            val start = maxOf(date.atStartOfDay(zone).toInstant(),activation)
            val end = minOf(date.plusDays(1).atStartOfDay(zone).toInstant(),Instant.now())
            if (start >= end) continue
            try {
                val count: Long
                val label: String
                if (source == "sensor") { count = prefs.getLong("steps:$date",0); label = "Phone walking session" }
                else if (client != null && allowed) {
                    count = client.aggregate(AggregateRequest(setOf(StepsRecord.COUNT_TOTAL),TimeRangeFilter.between(start,end)))[StepsRecord.COUNT_TOTAL] ?: 0
                    label = "Health Connect"
                    if (count > 0) prefs.edit().putString("source:$date","health-connect").apply()
                } else {
                    if (date == today) reply("steps",JSONObject().put("ok",false).put("message","Health Connect is unavailable. You can start a phone walking session."))
                    continue
                }
                reply("steps",JSONObject().put("ok",true).put("steps",count).put("date",date.toString()).put("source",label))
            } catch (e: Exception) { reply("steps",JSONObject().put("ok",false).put("message","Steps could not refresh. Check Health Connect access and try again.")) }
        }
    }
}
