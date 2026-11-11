package com.alanya237.alanya

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Pont Flutter → Telecom pour la sortie audio d'un appel.
 *
 * Canal dédié, et non `com.alanya/call_native` : ce dernier porte déjà un
 * gestionnaire côté Dart — les fins d'appel venues du natif — et un canal n'en
 * accepte qu'un par moteur. C'est aussi la convention du projet : un pont par
 * sujet (proximité, PiP, média d'appel).
 *
 * Pourquoi ne pas utiliser le `setAudioRoute` du plugin : sur Android, son
 * gestionnaire répond `result.success(true)` et ne fait rien d'autre
 * (`FlutterCallkitIncomingPlugin.kt:441`). Il rend « vrai » sans avoir rien
 * routé — c'est la réponse la plus trompeuse possible, et l'une des raisons
 * pour lesquelles le défaut a mis si longtemps à se laisser voir.
 */
object CallAudioBridge {

    private const val CHANNEL = "com.alanya237.alanya/call_audio"

    /**
     * Telecom applique la route sans rendre la main : demander puis relire
     * aussitôt donnerait l'ancienne sortie. On laisse passer un battement avant
     * de répondre, pour que l'interface affiche ce qui s'applique vraiment et
     * non ce qu'on a demandé.
     */
    private const val RELECTURE_MS = 250L

    fun attach(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            val callId = call.argument<String>("callId")?.trim().orEmpty()
            when (call.method) {
                "setRoute" -> {
                    val route = call.argument<String>("route")?.trim().orEmpty()
                    if (callId.isEmpty() || route.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    // Lue avant la demande : c'est la seule façon de reconnaître
                    // une relecture périmée. Ce que l'application croit ne suffit
                    // pas — elle peut croire le haut-parleur, posé par le chemin
                    // WebRTC, quand Telecom tient encore l'écouteur.
                    val avant = TelecomAudioRouter.read(callId)?.get("route")
                    if (!TelecomAudioRouter.apply(callId, route)) {
                        // Pas de connexion Telecom : `null` dit à Dart de
                        // retomber sur le chemin WebRTC.
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    Handler(Looper.getMainLooper()).postDelayed({
                        result.success(
                            TelecomAudioRouter.read(callId)?.plus("before" to avant),
                        )
                    }, RELECTURE_MS)
                }

                "readRoute" -> {
                    result.success(
                        if (callId.isEmpty()) null else TelecomAudioRouter.read(callId),
                    )
                }

                else -> result.notImplemented()
            }
        }
    }
}
