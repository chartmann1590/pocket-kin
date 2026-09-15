package com.pocketkin.game

import android.content.ComponentName
import android.content.Context
import android.util.Log
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import com.google.android.gms.wearable.*
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.UUID

enum class SyncMode {
    BLUETOOTH,
    INTERNET_FALLBACK,
    OFFLINE
}

class SyncManager(
    private val context: Context,
    private val scope: CoroutineScope,
    private val onStateUpdated: (JSONObject, SyncMode) -> Unit,
    private val onMessage: (String) -> Unit
) : MessageClient.OnMessageReceivedListener, DataClient.OnDataChangedListener {

    private val prefs = context.getSharedPreferences("kin_watch", Context.MODE_PRIVATE)
    var currentMode = SyncMode.OFFLINE
        private set
    var node: String? = null
        private set
    var lastSyncTime = 0L
        private set
    private var lastBtMessageTime = 0L
    private var pendingRequestId: String? = null
    private var heartbeatJob: Job? = null
    private var fallbackIp: String = "10.0.2.2"
    private var fallbackPort: Int = 8765
    private var lastWorkingBaseUrl: String? = null
    private var currentSnapshot: JSONObject = JSONObject()

    init {
        val cached = prefs.getString("snapshot", "{}") ?: "{}"
        currentSnapshot = runCatching { JSONObject(cached) }.getOrDefault(JSONObject())
        extractFallbackInfo(currentSnapshot)
    }

    fun start() {
        Wearable.getMessageClient(context).addListener(this)
        Wearable.getDataClient(context).addListener(this)
        startHeartbeat()
        refresh()
    }

    fun stop() {
        heartbeatJob?.cancel()
        Wearable.getMessageClient(context).removeListener(this)
        Wearable.getDataClient(context).removeListener(this)
    }

    private fun extractFallbackInfo(snapshot: JSONObject) {
        val ip = snapshot.optString("phone_ip", "")
        if (ip.isNotBlank() && ip != "127.0.0.1") {
            fallbackIp = ip
        }
        val port = snapshot.optInt("server_port", 8765)
        if (port > 0) fallbackPort = port
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isActive) {
                syncCycle()
                delay(2000)
            }
        }
    }

    fun refresh() = scope.launch {
        syncCycle()
    }

    private suspend fun syncCycle() {
        // 1. Primary: Bluetooth Check
        val nodes = runCatching {
            Wearable.getNodeClient(context).connectedNodes.await()
        }.getOrDefault(emptyList())

        val btNode = nodes.firstOrNull()?.id
        if (btNode != null) {
            node = btNode
            runCatching {
                Wearable.getMessageClient(context).sendMessage(btNode, "/kin/ping", byteArrayOf()).await()
            }
        } else {
            node = null
        }

        val isBtActive = (System.currentTimeMillis() - lastBtMessageTime < 4500L) && (node != null)
        if (isBtActive) {
            if (currentMode != SyncMode.BLUETOOTH) {
                currentMode = SyncMode.BLUETOOTH
                onMessage("Connected via Bluetooth")
            }
            return
        }

        // 2. Fallback: Internet / Local HTTP Sync
        val fetched = fetchStateOverInternet()
        if (fetched) {
            if (currentMode != SyncMode.INTERNET_FALLBACK) {
                currentMode = SyncMode.INTERNET_FALLBACK
            }
        } else if (System.currentTimeMillis() - lastSyncTime > 15000L) {
            if (currentMode != SyncMode.OFFLINE) {
                currentMode = SyncMode.OFFLINE
                onMessage("Offline · showing saved view")
            }
        }
    }

    private fun getCandidateUrls(): List<String> {
        val list = mutableListOf<String>()
        lastWorkingBaseUrl?.let { list.add(it) }
        list.add("http://127.0.0.1:$fallbackPort")
        list.add("http://10.0.2.2:$fallbackPort")
        if (fallbackIp.isNotBlank() && fallbackIp != "127.0.0.1" && fallbackIp != "10.0.2.2") {
            list.add("http://$fallbackIp:$fallbackPort")
        }
        return list.distinct()
    }

    private suspend fun fetchStateOverInternet(): Boolean = withContext(Dispatchers.IO) {
        val candidates = getCandidateUrls()

        for (base in candidates) {
            try {
                val url = URL("$base/kin/state")
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 1500
                conn.readTimeout = 1500
                conn.requestMethod = "GET"
                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream, StandardCharsets.UTF_8))
                    val body = reader.readText()
                    reader.close()
                    conn.disconnect()

                    val data = JSONObject(body)
                    lastWorkingBaseUrl = base
                    val newRev = data.optLong("revision", -1L)
                    val curRev = currentSnapshot.optLong("revision", -1L)
                    val newPet = data.optJSONObject("pet")
                    val curPet = currentSnapshot.optJSONObject("pet")
                    val petChanged = (newPet != null && (curPet == null || newPet.toString() != curPet.toString()))

                    withContext(Dispatchers.Main) {
                        currentMode = SyncMode.INTERNET_FALLBACK
                        lastSyncTime = System.currentTimeMillis()
                        if (newRev > curRev || petChanged) {
                            currentSnapshot = data
                            cacheState(data)
                            onStateUpdated(data, SyncMode.INTERNET_FALLBACK)
                            onMessage("Internet Synced")
                        }
                    }
                    return@withContext true
                }
                conn.disconnect()
            } catch (e: Exception) {
                Log.w("SyncManager", "State fetch from $base failed: ${e.message}")
            }
        }
        false
    }

    suspend fun sendAction(
        action: String,
        snapshot: JSONObject,
        extra: JSONObject = JSONObject()
    ): Boolean {
        val requestId = UUID.randomUUID().toString()
        pendingRequestId = requestId

        val pet = snapshot.optJSONObject("pet") ?: JSONObject()
        val input = extra
            .put("id", requestId)
            .put("action", action)
            .put("pet_id", pet.optString("id"))
            .put("revision", snapshot.optLong("revision"))

        val isBtActive = (System.currentTimeMillis() - lastBtMessageTime < 5000L) && (node != null)

        // Primary: Bluetooth
        if (isBtActive) {
            val sent = runCatching {
                Wearable.getMessageClient(context).sendMessage(node!!, "/kin/action", input.toString().toByteArray()).await()
                true
            }.getOrDefault(false)

            if (sent) {
                onMessage("Sent via Bluetooth…")
                return true
            }
        }

        // Fallback: Internet
        onMessage("Sending via Internet Fallback…")
        val success = sendActionOverInternet(input)
        if (success) {
            currentMode = SyncMode.INTERNET_FALLBACK
            onMessage("Action updated via Internet")
            return true
        } else {
            onMessage("Sync failed. Check connection.")
            return false
        }
    }

    private suspend fun sendActionOverInternet(input: JSONObject): Boolean = withContext(Dispatchers.IO) {
        val candidates = getCandidateUrls()
        val jsonStr = input.toString()

        for (base in candidates) {
            try {
                val url = URL("$base/kin/action")
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 3000
                conn.readTimeout = 3000
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                val writer = OutputStreamWriter(conn.outputStream, StandardCharsets.UTF_8)
                writer.write(jsonStr)
                writer.flush()
                writer.close()

                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream, StandardCharsets.UTF_8))
                    val body = reader.readText()
                    reader.close()
                    conn.disconnect()

                    val res = JSONObject(body)
                    if (res.optBoolean("ok", false)) {
                        lastWorkingBaseUrl = base
                        val newSnapshot = res.optJSONObject("snapshot")
                        if (newSnapshot != null) {
                            currentSnapshot = newSnapshot
                            cacheState(newSnapshot)
                            withContext(Dispatchers.Main) {
                                onStateUpdated(newSnapshot, SyncMode.INTERNET_FALLBACK)
                            }
                        } else {
                            fetchStateOverInternet()
                        }
                        return@withContext true
                    }
                }
                conn.disconnect()
            } catch (e: Exception) {
                Log.w("SyncManager", "Action via $base failed: ${e.message}")
            }
        }
        false
    }

    suspend fun syncHealth(healthPayload: JSONObject) {
        val isBtActive = (System.currentTimeMillis() - lastBtMessageTime < 5000L) && (node != null)

        // Bluetooth
        if (isBtActive) {
            val ok = runCatching {
                Wearable.getMessageClient(context).sendMessage(node!!, "/kin/sync_health", healthPayload.toString().toByteArray()).await()
                true
            }.getOrDefault(false)
            if (ok) return
        }

        // Fallback: Internet
        withContext(Dispatchers.IO) {
            val candidates = getCandidateUrls()
            val jsonStr = healthPayload.toString()
            for (base in candidates) {
                try {
                    val url = URL("$base/kin/sync_health")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.connectTimeout = 2500
                    conn.readTimeout = 2500
                    conn.requestMethod = "POST"
                    conn.doOutput = true
                    conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    val writer = OutputStreamWriter(conn.outputStream, StandardCharsets.UTF_8)
                    writer.write(jsonStr)
                    writer.flush()
                    writer.close()
                    val code = conn.responseCode
                    conn.disconnect()
                    if (code == 200) {
                        lastWorkingBaseUrl = base
                        return@withContext
                    }
                } catch (_: Exception) {}
            }
        }
    }

    override fun onMessageReceived(event: MessageEvent) {
        scope.launch(Dispatchers.Main) {
            val data = runCatching { JSONObject(String(event.data)) }.getOrNull() ?: return@launch
            if (event.path == "/kin/state") {
                lastBtMessageTime = System.currentTimeMillis()
                currentMode = SyncMode.BLUETOOTH
                lastSyncTime = System.currentTimeMillis()
                currentSnapshot = data
                cacheState(data)
                onStateUpdated(data, SyncMode.BLUETOOTH)
                onMessage("Bluetooth Synced")
            }
            if (event.path == "/kin/ack" && data.optString("id") == pendingRequestId) {
                lastBtMessageTime = System.currentTimeMillis()
                pendingRequestId = null
                onMessage(if (data.optBoolean("ok")) "A gentle moment, shared 💕" else "Refreshing pet view…")
                refresh()
            }
        }
    }

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == "/kin/state") {
                val text = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
                val json = runCatching { JSONObject(text) }.getOrNull() ?: continue
                scope.launch(Dispatchers.Main) {
                    lastBtMessageTime = System.currentTimeMillis()
                    currentMode = SyncMode.BLUETOOTH
                    lastSyncTime = System.currentTimeMillis()
                    currentSnapshot = json
                    cacheState(json)
                    onStateUpdated(json, SyncMode.BLUETOOTH)
                    onMessage("Bluetooth Synced")
                }
            }
        }
    }

    private fun cacheState(data: JSONObject) {
        extractFallbackInfo(data)
        prefs.edit()
            .putString("snapshot", data.toString())
            .putLong("synced", System.currentTimeMillis())
            .apply()
        runCatching { TileService.getUpdater(context).requestUpdate(KinTileService::class.java) }
        runCatching {
            ComplicationDataSourceUpdateRequester.create(
                context,
                ComponentName(context, KinComplication::class.java)
            ).requestUpdateAll()
        }
    }
}
