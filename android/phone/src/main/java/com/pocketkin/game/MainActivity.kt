package com.pocketkin.game

import android.content.Intent
import android.os.Bundle
import androidx.core.view.ViewCompat
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import org.godotengine.godot.GodotActivity
import org.json.JSONObject

class MainActivity : GodotActivity() {
    override fun getCommandLine(): MutableList<String> = mutableListOf("--main-pack", "res://pocket-kin.pck", "--rendering-method", "gl_compatibility")

    // Health Connect permissions must be requested through the Activity Result
    // API. On Android 14+ the connect-client permission contract delegates to
    // the platform permission flow, and the intent it builds is only valid
    // when launched from a registered launcher: firing it with
    // startActivityForResult() fails inside ActivityTaskManager
    // (START_CLASS_NOT_FOUND) and no permission sheet is ever shown.
    private val healthPermissionsLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) {
        KinPlugin.current.get()?.healthPermissionRequestFinished()
    }

    fun requestHealthPermissions() {
        healthPermissionsLauncher.launch(setOf(HealthPermission.getReadPermission(StepsRecord::class)))
    }

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
