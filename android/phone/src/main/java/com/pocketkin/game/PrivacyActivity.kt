package com.pocketkin.game
import android.app.Activity
import android.os.Bundle
import android.widget.TextView
class PrivacyActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        setContentView(TextView(this).apply {
            textSize=19f; setPadding(32,70,32,32)
            text="Walking with Pocket Kin\n\nWith your permission, Pocket Kin reads your step totals to give your pet optional happiness and adventure rewards. It does not read location, heart rate, routes, or other health records, and never writes health data.\n\nStep records stay on your phone. Only resulting game progress is included in cloud saves. Health information is not shared with advertising or analytics services.\n\nYou can revoke step access in Health Connect at any time. All care and progression remain available through regular play.\n\nOptional cloud saves use Firebase. Optional ads use Google AdMob with privacy controls in Settings. Purchases use Google Play."
        })
    }
}
