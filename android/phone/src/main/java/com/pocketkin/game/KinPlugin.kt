package com.pocketkin.game

import android.app.Activity
import android.content.Intent
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.lang.ref.WeakReference

class KinPlugin(godot: Godot) : GodotPlugin(godot) {
    companion object { 
        var current: WeakReference<KinPlugin> = WeakReference(null) 
        var pendingWidgetPage: String? = null
    }
    private val services by lazy { KinServices(requireNotNull(activity), ::reply) }
    override fun getPluginName() = "PocketKin"
    override fun getPluginSignals() = setOf(SignalInfo("result", String::class.java, String::class.java))
    @UsedByGodot fun request(kind: String, raw: String) {
        activity?.runOnUiThread {
            try { 
                current = WeakReference(this)
                flushPendingWidget()
                services.request(kind, JSONObject(raw)) 
            }
            catch (e: Exception) { reply(kind, JSONObject().put("ok", false).put("message", e.message ?: "Please try again.")) }
        }
    }
    fun flushPendingWidget() {
        pendingWidgetPage?.let { page ->
            pendingWidgetPage = null
            reply("widget_open", JSONObject().put("page", page))
        }
    }
    fun reply(kind: String, payload: JSONObject) { emitSignal("result", kind, payload.toString()) }
    fun isPaused() = services.paused
    fun openWidget() = services.openWidget()
    override fun onMainResume() { 
        current = WeakReference(this)
        services.resume()
        flushPendingWidget()
    }
    override fun onMainPause() { services.paused = true }
    override fun onMainDestroy() { current.clear(); services.close() }
    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) { services.activityResult(requestCode, resultCode, data) }
    override fun onMainRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) { services.permissionResult(requestCode, grantResults) }
}
