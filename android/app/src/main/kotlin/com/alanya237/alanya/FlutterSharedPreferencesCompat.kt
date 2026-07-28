package com.alanya237.alanya

import android.content.SharedPreferences

/**
 * Lecture des clés écrites par le plugin Flutter `shared_preferences`.
 * Les entiers y sont stockés en [Long] — un [SharedPreferences.getString]
 * provoque un ClassCastException.
 */
object FlutterSharedPreferencesCompat {
    private const val FLUTTER_PREFIX = "flutter."

    fun intKey(dartKey: String): String = FLUTTER_PREFIX + dartKey

    fun readInt(prefs: SharedPreferences, dartKey: String): Int? {
        val key = intKey(dartKey)
        if (!prefs.contains(key)) return null
        return when (val value = prefs.all[key]) {
            is Int -> value
            is Long -> value.toInt()
            is String -> value.toIntOrNull()
            else -> null
        }
    }
}
