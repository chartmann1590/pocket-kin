package com.pocketkin.game

import android.content.Context
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import org.json.JSONObject

/**
 * On-device translation with Google ML Kit.
 *
 * Godot sends "translate_batch" with a target language and the English strings
 * collected from the UI; this bridge downloads the language model if needed and
 * replies with "translations" ({english -> translated}) which I18n.gd caches in
 * the save file. "download_language" pre-downloads a model when the player picks
 * a language, replying with "language_ready".
 *
 * English is the source for every batch, so a single Translator per target
 * language is enough; it is cached for the session and closed on release().
 */
class TranslationBridge(private val context: Context, private val reply: (String, JSONObject) -> Unit) {

    companion object {
        private fun mlCode(bcp47: String): String? = try {
            TranslateLanguage.fromLanguageTag(bcp47)
        } catch (e: Exception) {
            null
        }
    }

    private val translators = HashMap<String, Translator>()

    fun request(kind: String, input: JSONObject) {
        when (kind) {
            "translate_batch" -> translateBatch(input.optString("lang", ""), input)
            "download_language" -> downloadLanguage(input.optString("lang", ""))
        }
    }

    fun release() {
        for (translator in translators.values) runCatching { translator.close() }
        translators.clear()
    }

    private fun translator(lang: String): Translator? {
        val code = mlCode(lang) ?: return null
        translators[lang]?.let { return it }
        val options = TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(code)
            .build()
        val translator = Translation.getClient(options)
        translators[lang] = translator
        return translator
    }

    private fun translateBatch(lang: String, input: JSONObject) {
        val translator = translator(lang)
        if (translator == null) {
            reply("translations", JSONObject().put("ok", false).put("lang", lang).put("message", "Unsupported language: $lang"))
            return
        }
        val strings = mutableListOf<String>()
        input.optJSONArray("strings")?.let { arr ->
            for (i in 0 until arr.length()) strings.add(arr.optString(i))
        }
        if (strings.isEmpty()) {
            reply("translations", JSONObject().put("ok", true).put("lang", lang).put("map", JSONObject()))
            return
        }
        translator.downloadModelIfNeeded()
            .addOnSuccessListener {
                val tasks = strings.map { str -> translator.translate(str) }
                Tasks.whenAllSuccess<String>(tasks)
                    .addOnSuccessListener { translated ->
                        val map = JSONObject()
                        for (i in strings.indices) {
                            if (i < translated.size) map.put(strings[i], translated[i])
                        }
                        reply("translations", JSONObject().put("ok", true).put("lang", lang).put("map", map))
                    }
                    .addOnFailureListener { e ->
                        reply("translations", JSONObject().put("ok", false).put("lang", lang).put("message", e.message ?: "Translation failed."))
                    }
            }
            .addOnFailureListener { e ->
                reply("translations", JSONObject().put("ok", false).put("lang", lang).put("message", e.message ?: "Could not download the translation model."))
            }
    }

    private fun downloadLanguage(lang: String) {
        val translator = translator(lang)
        if (translator == null) {
            reply("language_ready", JSONObject().put("ok", false).put("lang", lang).put("message", "Unsupported language: $lang"))
            return
        }
        translator.downloadModelIfNeeded()
            .addOnSuccessListener {
                reply("language_ready", JSONObject().put("ok", true).put("lang", lang))
            }
            .addOnFailureListener { e ->
                reply("language_ready", JSONObject().put("ok", false).put("lang", lang).put("message", e.message ?: "Could not download the translation model."))
            }
    }
}
