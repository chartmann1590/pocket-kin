package com.pocketkin.game

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.*
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets

object PhoneSyncServer {
    private const val TAG = "PhoneSyncServer"
    const val PORT = 8765
    private var serverSocket: ServerSocket? = null
    private var job: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var appContext: Context? = null
    @Volatile
    var latestSnapshot: JSONObject? = null

    @Synchronized
    fun start(context: Context) {
        if (job?.isActive == true && serverSocket?.isClosed == false) return
        appContext = context.applicationContext
        job = scope.launch {
            try {
                serverSocket = ServerSocket(PORT)
                Log.i(TAG, "PhoneSyncServer listening on port $PORT")
                while (isActive) {
                    val socket = serverSocket?.accept() ?: break
                    launch(Dispatchers.IO) { handleClient(socket) }
                }
            } catch (e: Exception) {
                if (e !is java.net.SocketException) {
                    Log.e(TAG, "Server error: ${e.message}", e)
                }
            }
        }
    }

    @Synchronized
    fun stop() {
        try {
            job?.cancel()
            serverSocket?.close()
            serverSocket = null
        } catch (e: Exception) {
            Log.w(TAG, "Error closing server: ${e.message}")
        }
    }

    private fun handleClient(socket: Socket) {
        try {
            socket.soTimeout = 8000
            val input = BufferedReader(InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8))
            val output = OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8)

            val requestLine = input.readLine() ?: return
            val parts = requestLine.split(" ")
            if (parts.size < 2) return
            val method = parts[0]
            val path = parts[1]

            var contentLength = 0
            var line: String? = input.readLine()
            while (!line.isNullOrEmpty()) {
                if (line.lowercase().startsWith("content-length:")) {
                    contentLength = line.substring(15).trim().toIntOrNull() ?: 0
                }
                line = input.readLine()
            }

            var body = ""
            if (contentLength > 0) {
                val buf = CharArray(contentLength)
                var read = 0
                while (read < contentLength) {
                    val count = input.read(buf, read, contentLength - read)
                    if (count < 0) break
                    read += count
                }
                body = String(buf, 0, read)
            }

            val response = processRequest(method, path, body)
            val bytes = response.toByteArray(StandardCharsets.UTF_8)

            output.write("HTTP/1.1 200 OK\r\n")
            output.write("Content-Type: application/json; charset=utf-8\r\n")
            output.write("Content-Length: ${bytes.size}\r\n")
            output.write("Access-Control-Allow-Origin: *\r\n")
            output.write("Connection: close\r\n\r\n")
            output.write(response)
            output.flush()
        } catch (e: Exception) {
            Log.w(TAG, "Client handle exception: ${e.message}")
        } finally {
            runCatching { socket.close() }
        }
    }

    private fun processRequest(method: String, path: String, body: String): String {
        val ctx = appContext ?: return JSONObject().put("ok", false).put("message", "Service initializing").toString()
        val prefs = ctx.getSharedPreferences("kin_native", 0)

        when {
            path == "/kin/ping" -> {
                return JSONObject()
                    .put("ok", true)
                    .put("server", "PocketKin-Phone")
                    .put("time", System.currentTimeMillis())
                    .toString()
            }
            path == "/kin/state" && method == "GET" -> {
                val mem = latestSnapshot?.toString()
                if (!mem.isNullOrEmpty()) return mem
                val snapshotStr = prefs.getString("snapshot", "{}") ?: "{}"
                return snapshotStr
            }
            path == "/kin/action" && method == "POST" -> {
                val inputJson = runCatching { JSONObject(body) }.getOrDefault(JSONObject())
                val id = inputJson.optString("id")
                val ack = JSONObject().put("id", id).put("ok", false)

                val plugin = KinPlugin.current.get()
                if (plugin != null && !plugin.isPaused()) {
                    plugin.reply("watch_action", inputJson)
                    ack.put("ok", true)
                    runCatching { Thread.sleep(80) }
                    val snap = latestSnapshot ?: runCatching { JSONObject(prefs.getString("snapshot", "{}") ?: "{}") }.getOrNull()
                    if (snap != null) ack.put("snapshot", snap)
                    return ack.toString()
                }

                val pathStr = prefs.getString("save_path", "") ?: ""
                val file = File(pathStr)
                val valid = file.canonicalPath.startsWith(ctx.filesDir.canonicalPath + File.separator) && file.isFile
                if (valid) synchronized(PhoneWatchService::class.java) {
                    runCatching {
                        val save = JSONObject(file.readText())
                        val outcome = NativeCare.apply(save, inputJson, System.currentTimeMillis() / 1000.0)
                        ack.put("ok", outcome).put("revision", save.optLong("revision"))
                        if (outcome) {
                            val temporary = File(pathStr + ".watch.tmp")
                            temporary.writeText(save.toString())
                            file.copyTo(File(pathStr + ".bak"), overwrite = true)
                            check(temporary.renameTo(file))
                            prefs.edit().putBoolean("external_save_changed", true).apply()

                            val snapshot = JSONObject(prefs.getString("snapshot", "{}") ?: "{}")
                            snapshot.put("pet", save.getJSONObject("pet")).put("revision", save.optLong("revision"))
                            prefs.edit().putString("snapshot", snapshot.toString()).apply()

                            KinWidget.update(ctx)
                            CareScheduler.schedule(ctx)

                            val data = PutDataMapRequest.create("/kin/state")
                            data.dataMap.putString("json", snapshot.toString())
                            data.dataMap.putLong("synced", System.currentTimeMillis())
                            Wearable.getDataClient(ctx).putDataItem(data.asPutDataRequest().setUrgent())

                            ack.put("snapshot", snapshot)
                        }
                    }
                }
                return ack.toString()
            }
            path == "/kin/sync_health" && method == "POST" -> {
                val data = runCatching { JSONObject(body) }.getOrDefault(JSONObject())
                val steps = data.optInt("steps", 0)
                val hr = data.optInt("heart_rate", 0)
                val hydration = data.optInt("hydration", 0)
                val activeMin = data.optInt("active_minutes", 0)
                val calories = data.optInt("calories", 0)

                prefs.edit()
                    .putInt("watch_steps", steps)
                    .putInt("watch_heart_rate", hr)
                    .putInt("watch_hydration", hydration)
                    .putInt("watch_active_min", activeMin)
                    .putInt("watch_calories", calories)
                    .putLong("watch_health_synced", System.currentTimeMillis())
                    .apply()

                val plugin = KinPlugin.current.get()
                if (plugin != null && !plugin.isPaused()) {
                    plugin.reply("watch_health", data)
                }

                // Reconcile watch steps with save file if higher
                val pathStr = prefs.getString("save_path", "") ?: ""
                val file = File(pathStr)
                if (steps > 0 && file.isFile) synchronized(PhoneWatchService::class.java) {
                    runCatching {
                        val save = JSONObject(file.readText())
                        val walking = save.optJSONObject("walking") ?: JSONObject()
                        val currentSteps = walking.optInt("steps", 0)
                        if (steps > currentSteps) {
                            walking.put("steps", steps)
                            walking.put("updated", System.currentTimeMillis() / 1000.0)
                            walking.put("source", "watch")
                            save.put("walking", walking)
                            file.writeText(save.toString())
                            prefs.edit().putBoolean("external_save_changed", true).apply()
                            KinWidget.update(ctx)
                        }
                    }
                }

                return JSONObject().put("ok", true).put("message", "Watch health synchronized").toString()
            }
            else -> {
                return JSONObject().put("ok", false).put("message", "Not found").toString()
            }
        }
    }

    fun getLocalIpAddress(context: Context): String {
        return runCatching {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val ipInt = wifiManager?.connectionInfo?.ipAddress ?: 0
            if (ipInt != 0) {
                String.format(
                    java.util.Locale.US,
                    "%d.%d.%d.%d",
                    ipInt and 0xff,
                    ipInt shr 8 and 0xff,
                    ipInt shr 16 and 0xff,
                    ipInt shr 24 and 0xff
                )
            } else {
                val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
                var fallback = "127.0.0.1"
                while (interfaces.hasMoreElements()) {
                    val intf = interfaces.nextElement()
                    val addrs = intf.inetAddresses
                    while (addrs.hasMoreElements()) {
                        val addr = addrs.nextElement()
                        if (!addr.isLoopbackAddress && addr is java.net.Inet4Address) {
                            fallback = addr.hostAddress ?: fallback
                            break
                        }
                    }
                }
                fallback
            }
        }.getOrDefault("127.0.0.1")
    }
}
