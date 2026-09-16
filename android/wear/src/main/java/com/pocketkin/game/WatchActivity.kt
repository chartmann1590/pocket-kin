package com.pocketkin.game

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.*
import kotlinx.coroutines.*
import org.json.JSONObject

class WatchActivity : ComponentActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var syncManager: SyncManager
    private lateinit var healthManager: WatchHealthManager

    private var snapshot by mutableStateOf(JSONObject())
    private var syncMode by mutableStateOf(SyncMode.OFFLINE)
    private var statusMessage by mutableStateOf("Connecting to your phone…")
    private var pendingAction by mutableStateOf(false)

    // Rhythm mini game state
    private var playingRhythm by mutableStateOf(false)
    private var rhythmSeconds by mutableIntStateOf(20)
    private var rhythmHits by mutableIntStateOf(0)
    private var rhythmBeat by mutableIntStateOf(0)

    // Touch petting game state
    private var pettingCount by mutableIntStateOf(0)
    private var pettingJoyText by mutableStateOf("")

    // Health state
    private var todaySteps by mutableIntStateOf(0)
    private var heartRate by mutableIntStateOf(74)
    private var hydrationCups by mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val cached = getSharedPreferences("kin_watch", 0).getString("snapshot", "{}") ?: "{}"
        snapshot = runCatching { JSONObject(cached) }.getOrDefault(JSONObject())

        healthManager = WatchHealthManager(this) { healthData ->
            todaySteps = healthManager.getTodaySteps()
            heartRate = healthManager.getHeartRate()
            hydrationCups = healthManager.getHydrationCups()
            scope.launch { syncManager.syncHealth(healthData) }
        }
        todaySteps = healthManager.getTodaySteps()
        heartRate = healthManager.getHeartRate()
        hydrationCups = healthManager.getHydrationCups()

        syncManager = SyncManager(
            context = this,
            scope = scope,
            onStateUpdated = { newSnapshot, mode ->
                snapshot = newSnapshot
                syncMode = mode
                pendingAction = false
            },
            onMessage = { msg ->
                statusMessage = msg
            }
        )

        setContent {
            val colors = Colors(
                primary = Color(0xFFA8C496),
                primaryVariant = Color(0xFF7A9E64),
                secondary = Color(0xFFF3C785),
                background = Color(0xFF161E15),
                surface = Color(0xFF222D21),
                onPrimary = Color(0xFF182216),
                onBackground = Color(0xFFFFFDF8),
                onSurface = Color(0xFFECE5D8)
            )
            MaterialTheme(colors = colors) {
                WatchMainScreen()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        healthManager.registerSensors()
        syncManager.start()
        scope.launch { syncManager.syncHealth(healthManager.getHealthPayload()) }
    }

    override fun onPause() {
        healthManager.unregisterSensors()
        syncManager.stop()
        playingRhythm = false
        super.onPause()
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun vibrate(millis: Long = 30) {
        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
        vibrator?.let {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                it.vibrate(VibrationEffect.createOneShot(millis, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(millis)
            }
        }
    }

    private fun performCare(action: String) {
        if (pendingAction) return
        val pet = snapshot.optJSONObject("pet") ?: return
        if (!pet.has("id")) return
        vibrate(40)
        pendingAction = true
        scope.launch {
            val ok = syncManager.sendAction(action, snapshot)
            if (!ok) pendingAction = false
        }
    }

    private fun startRhythmPlay() {
        playingRhythm = true
        rhythmSeconds = 20
        rhythmHits = 0
        scope.launch {
            for (tick in 0 until 40) {
                if (!playingRhythm) return@launch
                rhythmBeat = if (tick % 3 == 2) 1 else 0
                delay(500)
                rhythmSeconds = 20 - (tick + 1) / 2
            }
            playingRhythm = false
            performCareWithExtra("watch_play", JSONObject().put("duration", 20).put("hits", rhythmHits))
        }
    }

    private fun performCareWithExtra(action: String, extra: JSONObject) {
        val pet = snapshot.optJSONObject("pet") ?: return
        pendingAction = true
        scope.launch {
            syncManager.sendAction(action, snapshot, extra)
            pendingAction = false
        }
    }

    @Composable
    private fun WatchMainScreen() {
        val pet = snapshot.optJSONObject("pet") ?: JSONObject()
        val hasPet = pet.has("id")
        val walking = snapshot.optJSONObject("walking") ?: JSONObject()
        val combinedSteps = maxOf(todaySteps, walking.optInt("steps", 0))

        // Gentle breathing animation for pet
        val infiniteTransition = rememberInfiniteTransition(label = "pet_breath")
        val bounceOffset by infiniteTransition.animateFloat(
            initialValue = -3f,
            targetValue = 3f,
            animationSpec = infiniteRepeatable(
                animation = tween(1200, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "bounce"
        )

        ScalingLazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF161E15)),
            horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 24.dp)
        ) {
            // App Title
            item {
                Text(
                    text = "pocket kin",
                    color = Color(0xFFE2D0B6),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            // Sync Status Pill
            item {
                val (badgeColor, badgeText) = when (syncMode) {
                    SyncMode.BLUETOOTH -> Color(0xFF7CB342) to "🟢 Bluetooth Synced"
                    SyncMode.INTERNET_FALLBACK -> Color(0xFF29B6F6) to "🌐 Internet Fallback"
                    SyncMode.OFFLINE -> Color(0xFFFFA726) to "💾 Saved View (Offline)"
                }
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(badgeColor.copy(alpha = 0.2f))
                        .padding(horizontal = 10.dp, vertical = 3.dp)
                ) {
                    Text(
                        text = badgeText,
                        color = badgeColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // Pet Avatar Display
            item {
                val species = pet.optInt("species", 0)
                val stage = pet.optString("stage", "baby")
                val sleeping = pet.optBoolean("sleeping", false)
                val bitmap = remember(species, stage, sleeping) { petBitmap(pet) }

                Box(
                    modifier = Modifier
                        .padding(top = 4.dp)
                        .offset(y = bounceOffset.dp)
                        .size(105.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF253424))
                        .clickable {
                            // Touch petting on watch
                            pettingCount++
                            vibrate(25)
                            val cheers = listOf("Purrr! 💕", "Hehe! ✨", "So soft! 🌸", "Loved! 💖")
                            pettingJoyText = cheers.random()
                            if (pettingCount % 5 == 0) {
                                performCare("love")
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "Pet",
                        modifier = Modifier.size(95.dp)
                    )
                }
            }

            // Pet Name & Stage
            item {
                val petName = if (hasPet) pet.optString("name", "Little Friend") else "An egg is waiting!"
                Text(
                    text = petName,
                    color = Color(0xFFFFFDF8),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
            }

            // Mood & Quote
            item {
                val moodText = when {
                    !hasPet -> "Open phone to hatch your egg"
                    pet.optBoolean("sleeping") -> "Dreaming sweet dreams… 💤"
                    pet.optBoolean("ill") -> "Feeling poorly · needs care 🩹"
                    pettingJoyText.isNotBlank() -> pettingJoyText
                    pet.optInt("happiness") > 80 -> "Full of happy wiggles! 🌟"
                    pet.optInt("hunger") < 35 -> "A tiny bit hungry 🍎"
                    else -> "Cozy and content 🌿"
                }
                Text(
                    text = moodText,
                    color = Color(0xFFC0D0BA),
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 8.dp)
                )
            }

            if (statusMessage.isNotBlank() && statusMessage != "Just updated") {
                item {
                    Text(
                        text = statusMessage,
                        color = Color(0xFF9FB29A),
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center
                    )
                }
            }

            // Rhythm Mini-Game Mode
            if (playingRhythm) {
                item {
                    Card(
                        onClick = {},
                        modifier = Modifier.fillMaxWidth(),
                        backgroundPainter = CardDefaults.cardBackgroundPainter(Color(0xFF243523))
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("$rhythmSeconds s · $rhythmHits beats", color = Color(0xFFFFFDF8), fontSize = 13.sp)
                            Spacer(Modifier.height(6.dp))
                            Button(
                                onClick = {
                                    if (rhythmBeat == 1) {
                                        rhythmHits++
                                        rhythmBeat = 0
                                        vibrate(30)
                                    }
                                },
                                colors = ButtonDefaults.buttonColors(backgroundColor = if (rhythmBeat == 1) Color(0xFFF3C785) else Color(0xFF3B4F3A)),
                                modifier = Modifier.fillMaxWidth(0.85f)
                            ) {
                                Text(if (rhythmBeat == 1) "TAP! 🎵" else "Wait…", color = Color(0xFF182216), fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            } else {
                // Needs Meters Cards
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color(0xFF222E21))
                            .padding(10.dp)
                    ) {
                        val items = listOf(
                            Triple("hunger", "Fed", Color(0xFFF38C6C)),
                            Triple("happiness", "Happy", Color(0xFFF06292)),
                            Triple("cleanliness", "Clean", Color(0xFF4DB6AC)),
                            Triple("energy", "Rested", Color(0xFFFFB74D))
                        )
                        for ((key, title, color) in items) {
                            val value = pet.optInt(key, 80)
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 2.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(title, fontSize = 11.sp, color = Color(0xFFECE5D8))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .width(55.dp)
                                            .height(5.dp)
                                            .clip(RoundedCornerShape(3.dp))
                                            .background(Color(0xFF364835))
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .fillMaxHeight()
                                                .fillMaxWidth(value / 100f)
                                                .clip(RoundedCornerShape(3.dp))
                                                .background(color)
                                        )
                                    }
                                    Spacer(Modifier.width(6.dp))
                                    Text("$value%", fontSize = 10.sp, color = color, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }

                // Quick Care Actions
                item {
                    Text("Quick Care", color = Color(0xFFE2D0B6), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 4.dp))
                }

                item {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip(
                            onClick = { performCare("feed") },
                            enabled = hasPet && !pendingAction,
                            label = { Text("🍎 Feed", fontSize = 12.sp) },
                            colors = ChipDefaults.chipColors(backgroundColor = Color(0xFF2D3C2B)),
                            modifier = Modifier.weight(1f)
                        )
                        Chip(
                            onClick = { performCare("love") },
                            enabled = hasPet && !pendingAction,
                            label = { Text("💖 Cuddle", fontSize = 12.sp) },
                            colors = ChipDefaults.chipColors(backgroundColor = Color(0xFF2D3C2B)),
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                item {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Chip(
                            onClick = { performCare("clean") },
                            enabled = hasPet && !pendingAction,
                            label = { Text("🫧 Wash", fontSize = 12.sp) },
                            colors = ChipDefaults.chipColors(backgroundColor = Color(0xFF2D3C2B)),
                            modifier = Modifier.weight(1f)
                        )
                        Chip(
                            onClick = { performCare("sleep") },
                            enabled = hasPet && !pendingAction,
                            label = { Text("💤 Bed", fontSize = 12.sp) },
                            colors = ChipDefaults.chipColors(backgroundColor = Color(0xFF2D3C2B)),
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // Mini Game: Rhythm
                item {
                    Chip(
                        onClick = { startRhythmPlay() },
                        enabled = hasPet && !playingRhythm,
                        label = { Text("🎵 Raindrop Rhythm", fontSize = 12.sp) },
                        colors = ChipDefaults.chipColors(backgroundColor = Color(0xFF334631)),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Step Tracking & Adventure Progress
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color(0xFF202C1F))
                            .padding(10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("👟 Walking Adventure", color = Color(0xFFA8C496), fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "%,d / 3,000 steps".format(combinedSteps),
                            color = Color(0xFFFFFDF8),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(Modifier.height(4.dp))
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(8.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(Color(0xFF364835))
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxHeight()
                                    .fillMaxWidth((combinedSteps / 3000f).coerceIn(0f, 1f))
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(Color(0xFF7CB342))
                            )
                        }
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "Parcels: 500 · 1,500 · 3,000",
                            color = Color(0xFF9FB29A),
                            fontSize = 10.sp
                        )
                        Spacer(Modifier.height(6.dp))
                        Button(
                            onClick = {
                                val newTotal = healthManager.addSimulatedSteps(100)
                                todaySteps = newTotal
                                vibrate(25)
                                scope.launch { syncManager.syncHealth(healthManager.getHealthPayload()) }
                            },
                            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF364934)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("+100 Walk Steps 🐾", fontSize = 11.sp, color = Color(0xFFECE5D8))
                        }
                    }
                }

                // Health Tracking (Heart Harmony & Hydration)
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color(0xFF222B24))
                            .padding(10.dp)
                    ) {
                        Text("❤️ Pet Heartbeat Harmony", color = Color(0xFFF06292), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.height(4.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("$heartRate BPM", color = Color(0xFFFFFDF8), fontSize = 15.sp, fontWeight = FontWeight.Bold)
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(Color(0xFFF06292).copy(alpha = 0.2f))
                                    .clickable {
                                        heartRate = healthManager.measureHeartRatePulse()
                                        vibrate(40)
                                        scope.launch { syncManager.syncHealth(healthManager.getHealthPayload()) }
                                    }
                                    .padding(horizontal = 8.dp, vertical = 3.dp)
                            ) {
                                Text("Pulse 💓", color = Color(0xFFF06292), fontSize = 10.sp)
                            }
                        }
                        Text(
                            if (heartRate in 60..82) "Calm & Serene · +Friendship Boost" else "Active & Lively",
                            color = Color(0xFFB0C4AC),
                            fontSize = 10.sp
                        )

                        Spacer(Modifier.height(8.dp))
                        Text("💧 Daily Hydration", color = Color(0xFF4FC3F7), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("$hydrationCups / 8 cups", color = Color(0xFFFFFDF8), fontSize = 13.sp)
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(Color(0xFF4FC3F7).copy(alpha = 0.2f))
                                    .clickable {
                                        hydrationCups = healthManager.addHydrationCup()
                                        vibrate(30)
                                        scope.launch { syncManager.syncHealth(healthManager.getHealthPayload()) }
                                    }
                                    .padding(horizontal = 8.dp, vertical = 3.dp)
                            ) {
                                Text("+1 Sip 💧", color = Color(0xFF4FC3F7), fontSize = 10.sp)
                            }
                        }
                        Text(
                            "${healthManager.getActiveMinutes()} active min · ${healthManager.getCalories()} kcal",
                            color = Color(0xFFB0C4AC),
                            fontSize = 10.sp,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }

                // Refresh / Sync Button
                item {
                    Chip(
                        onClick = {
                            vibrate(20)
                            syncManager.refresh()
                            scope.launch { syncManager.syncHealth(healthManager.getHealthPayload()) }
                        },
                        label = { Text("🔄 Sync with Phone", fontSize = 12.sp) },
                        colors = ChipDefaults.chipColors(backgroundColor = Color(0xFF2C392B)),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }

    private fun petBitmap(pet: JSONObject): Bitmap {
        val names = listOf("mochi", "fern", "pebble", "clover", "pippin", "lumi")
        val speciesIndex = pet.optInt("species", 0).coerceIn(0, 5)
        val sheet = assets.open("pet_${names[speciesIndex]}.png").use { BitmapFactory.decodeStream(it) }
        val pose = if (pet.optBoolean("sleeping")) 5 else when (pet.optString("stage")) {
            "adult" -> 3
            "juvenile" -> 2
            else -> 1
        }
        val cell = Bitmap.createBitmap(sheet, (pose % 4) * sheet.width / 4, (pose / 4) * sheet.height / 2, sheet.width / 4, sheet.height / 2)
        return cell
    }
}
