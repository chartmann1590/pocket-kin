package com.pocketkin.game

import android.content.Context
import android.content.SharedPreferences

/**
 * Central access to the two phone-side prefs stores.
 *
 * - [game]: "kin_native" — gameplay state only (settings, screen, snapshot, save path,
 *   step counts per day). This file is in the backup/data-extraction allowlist.
 * - [private]: "kin_private" — ad consent + age-band state ("age_band", "last_ad").
 *   Never backed up or device-transferred; consent choices are re-asked on a new device.
 *
 * Rule of thumb: anything the store listing would call "advertising data" goes in
 * [private]; everything else goes in [game].
 */
object GamePrefs {
    const val GAME = "kin_native"
    const val PRIVATE = "kin_private"

    fun game(context: Context): SharedPreferences = context.getSharedPreferences(GAME, 0)
    fun private(context: Context): SharedPreferences = context.getSharedPreferences(PRIVATE, 0)
}
