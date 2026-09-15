package com.pocketkin.game

import android.content.Intent
import android.os.Bundle
import androidx.core.view.ViewCompat
import org.godotengine.godot.GodotActivity
import org.json.JSONObject

class MainActivity : GodotActivity() {
    override fun getCommandLine(): MutableList<String> = mutableListOf("--main-pack", "res://pocket-kin.pck", "--rendering-method", "gl_compatibility")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PhoneSyncServer.start(this)
        ViewCompat.setOnApplyWindowInsetsListener(window.decorView) { _, insets ->
            KinPlugin.current.get()?.request("insets", "{}")
            insets
        }
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        val page = intent?.getStringExtra("kin_widget_page")
            ?: intent?.data?.lastPathSegment
            ?: return
        intent?.removeExtra("kin_widget_page")
        val plugin = KinPlugin.current.get()
        if (plugin != null) {
            plugin.reply("widget_open", JSONObject().put("page", page))
        } else {
            KinPlugin.pendingWidgetPage = page
        }
    }
}
