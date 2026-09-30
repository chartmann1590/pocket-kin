package com.pocketkin.game
import android.app.Activity
import android.os.Bundle
import android.widget.TextView
class PrivacyActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        setContentView(TextView(this).apply {
            textSize=19f; setPadding(32,70,32,32)
            text="Walking with Pocket Kin\n\nWith your permission, Pocket Kin reads your step totals to give your pet optional happiness and adventure rewards. The phone app does not read location, routes, or other health records, and never writes health data. A paired Wear OS watch may share its step count and heart-rate reading with this app for the in-game mood bonus; those readings stay on your watch and phone.\n\nStep and heart-rate readings stay on your devices. Only resulting game progress is included in cloud saves. Health information is not shared with advertising or analytics services.\n\nYou can revoke step access in Health Connect, and body-sensor access on your watch, at any time. All care and progression remain available through regular play.\n\nOptional cloud saves use Firebase. Optional ads use Google AdMob with privacy controls in Settings. Purchases use Google Play."
        })
    }
}
