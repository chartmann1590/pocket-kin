package com.pocketkin.game

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import org.json.JSONObject

class KinWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = update(context)
    companion object {
        fun update(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val prefs = context.getSharedPreferences("kin_native", 0)
            val state = runCatching { JSONObject(prefs.getString("snapshot", "{}") ?: "{}") }.getOrDefault(JSONObject())
            val pet = state.optJSONObject("pet") ?: JSONObject()
            val walking = state.optJSONObject("walking") ?: JSONObject()
            val watchSteps = prefs.getInt("watch_steps", 0)
            val steps = maxOf(walking.optInt("steps", 0), watchSteps)

            val widgetIds = manager.getAppWidgetIds(ComponentName(context, KinWidget::class.java))
            for (id in widgetIds) {
                val view = RemoteViews(context.packageName, R.layout.kin_widget)
                val hasPet = pet.has("id")
                val name = if (hasPet) pet.optString("name", "Pocket Kin") else "Pocket Kin"
                view.setTextViewText(R.id.kin_name, name)

                val stage = if (hasPet) pet.optString("stage", "baby").replaceFirstChar { it.uppercase() } else "Egg"
                view.setTextViewText(R.id.kin_stage_badge, "✦ $stage")

                val hunger = pet.optInt("hunger", 85)
                val happiness = pet.optInt("happiness", 90)
                val sleeping = pet.optBoolean("sleeping", false)
                val ill = pet.optBoolean("ill", false)

                val moodText = when {
                    !hasPet -> "✨ Waiting"
                    sleeping -> "💤 Sleeping"
                    ill -> "🩹 Unwell"
                    hunger < 30 -> "🍎 Hungry"
                    happiness > 80 -> "💖 Joyful"
                    else -> "🌿 Content"
                }
                view.setTextViewText(R.id.kin_mood_badge, moodText)

                val statusText = when {
                    !hasPet -> "An egg is waiting for you"
                    sleeping -> "Dreaming sweet dreams"
                    else -> "Fed $hunger% · Happy $happiness%"
                }
                view.setTextViewText(R.id.kin_status, statusText)

                view.setProgressBar(R.id.kin_hunger_bar, 100, hunger.coerceIn(0, 100), false)
                view.setProgressBar(R.id.kin_happy_bar, 100, happiness.coerceIn(0, 100), false)
                view.setTextViewText(R.id.kin_steps, "👟 %,d / 3,000 steps".format(steps))

                val species = listOf("mochi", "fern", "pebble", "clover", "pippin", "lumi")[pet.optInt("species").coerceIn(0, 5)]
                runCatching {
                    val sheet = context.assets.open("widget/pet_$species.png").use { BitmapFactory.decodeStream(it) }
                    val pose = if (!hasPet) 0 else if (sleeping) 5 else when (pet.optString("stage")) { "adult" -> 3; "juvenile" -> 2; else -> 1 }
                    val cell = Bitmap.createBitmap(sheet, pose % 4 * sheet.width / 4, pose / 4 * sheet.height / 2, sheet.width / 4, sheet.height / 2)
                    view.setImageViewBitmap(R.id.kin_pet, Bitmap.createScaledBitmap(cell, 150, 200, true))
                    cell.recycle()
                    sheet.recycle()
                }

                val links = listOf(
                    R.id.kin_root to "Home",
                    R.id.kin_pet to "Home",
                    R.id.kin_care to "Feed",
                    R.id.kin_cuddle to "Love",
                    R.id.kin_walk to "Walk"
                )
                for ((target, page) in links) {
                    val intent = Intent(context, MainActivity::class.java).apply {
                        action = "com.pocketkin.open.$page"
                        data = android.net.Uri.parse("kin://open/$page")
                        putExtra("kin_widget_page", page)
                    }
                    view.setOnClickPendingIntent(target, PendingIntent.getActivity(context, target, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                }
                manager.updateAppWidget(id, view)
            }
        }
    }
}
