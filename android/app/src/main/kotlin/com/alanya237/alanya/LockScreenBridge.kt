package com.alanya237.alanya

import android.app.Activity
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Affichage de l'activité principale par-dessus l'écran de verrouillage.
 * Canal : `com.alanya237.alanya/lock_screen` (setShowWhenLocked).
 *
 * Réservé aux appels. Le réglage vivait en dur dans le manifeste et dans
 * `MainActivity.onCreate` : Alanya restait affichée par-dessus l'écran de
 * verrouillage en permanence, et quiconque rallumait un téléphone verrouillé
 * pendant qu'Alanya était au premier plan lisait les conversations sans code.
 *
 * La sonnerie entrante n'en a pas besoin : téléphone verrouillé, l'app passe en
 * arrière-plan et la sonnerie est confiée à l'écran plein de CallKit, qui a sa
 * propre activité. Il ne reste que l'appel décroché ou en cours, que l'on doit
 * retrouver en rallumant l'écran.
 */
object LockScreenBridge {
    private const val TAG = "LockScreenBridge"
    private const val CHANNEL = "com.alanya237.alanya/lock_screen"

    private var activityRef: WeakReference<Activity>? = null

    fun attach(messenger: BinaryMessenger, activity: Activity) {
        activityRef = WeakReference(activity)
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setShowWhenLocked" -> {
                    apply(call.argument<Boolean>("enabled") == true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Appelé aussi en natif : un décrochage depuis l'écran verrouillé lance
     * l'activité avant que Flutter ne soit prêt à le demander.
     */
    fun apply(enabled: Boolean, activity: Activity? = activityRef?.get()) {
        if (activity == null) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) return
        activity.runOnUiThread {
            try {
                activity.setShowWhenLocked(enabled)
                activity.setTurnScreenOn(enabled)
                Log.i(TAG, "showWhenLocked=$enabled")
            } catch (e: Exception) {
                Log.w(TAG, "setShowWhenLocked($enabled) échoué: ${e.message}")
            }
        }
    }
}
