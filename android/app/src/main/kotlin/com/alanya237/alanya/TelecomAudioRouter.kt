package com.alanya237.alanya

import android.os.Build
import android.telecom.CallAudioState
import android.telecom.Connection
import android.util.Log
import androidx.annotation.RequiresApi
import com.hiennv.flutter_callkit_incoming.CallkitConnection

/**
 * Applique la sortie audio d'un appel là où Android l'écoute vraiment : sur la
 * connexion Telecom.
 *
 * Depuis que chaque appel est déclaré à Telecom — compte auto-géré enregistré
 * par le plugin CallKit —, c'est le système qui possède le mode audio et la
 * route. Les demandes de l'application partaient, elles, vers
 * `AudioManager.setSpeakerphoneOn`, qu'il ignore. Mesuré sur appareil :
 * `dumpsys audio` montrait `selected mode … by pid=<telecom>`, la demande de
 * l'application marquée `Active: false`, et aucun changement de sortie venant
 * de notre identifiant. Le bouton semblait fonctionner et ne faisait rien.
 *
 * `setAudioRoute` est dépréciée depuis Android 14 au profit de
 * `requestCallEndpointChange`, mais celle-ci exige la liste des points de
 * terminaison, que seule une sous-classe de `Connection` reçoit — donc
 * inaccessible sans reprendre le plugin. La méthode dépréciée reste
 * fonctionnelle ; si un jour elle cesse de l'être, c'est ici, et ici seulement,
 * qu'il faudra changer.
 */
object TelecomAudioRouter {

    private const val TAG = "TelecomAudioRouter"

    /**
     * Demande [route] pour l'appel [callId].
     *
     * Rend `false` quand il n'y a pas de connexion Telecom : appel hors
     * Telecom, appareil antérieur à Android 8, ou connexion déjà détruite. À
     * l'appelant de retomber sur le chemin WebRTC.
     */
    fun apply(callId: String, route: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return appliquer(callId, route)
    }

    /**
     * Passe la connexion Telecom de [callId] à l'état actif si elle ne l'est pas.
     *
     * Le plugin déclare l'appel décroché par `placeCall`, qui est asynchrone :
     * la connexion naît ~200 ms plus tard. L'ordre « connecté » envoyé entre-
     * temps est jeté sans un mot (`driveTelecomConnection` : `find() ?: return`)
     * et l'appel reste DIALING. Sous Android 14+, le chien de garde de Telecom
     * le coupe alors à 120 s (`STATE_TIMEOUT`) : l'audio continue, mais Android
     * ne tient plus l'appel — plus de pastille, plus de mise en attente sur un
     * appel GSM, plus de route système. Mesuré sur un Xiaomi sous Android 16.
     *
     * Rend `null` sans connexion, sinon `true` si l'état a été changé.
     */
    fun activate(callId: String): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        val connexion = CallkitConnection.find(callId) ?: return null
        return try {
            if (connexion.state == Connection.STATE_ACTIVE) {
                false
            } else {
                Log.i(TAG, "connexion $callId en état ${connexion.state} → active")
                connexion.markAccepted()
                true
            }
        } catch (e: Exception) {
            Log.w(TAG, "activation impossible pour $callId: ${e.message}")
            null
        }
    }

    /** État réel de la sortie audio, ou `null` si Telecom ne tient pas l'appel. */
    fun read(callId: String): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        return lire(callId)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun appliquer(callId: String, route: String): Boolean {
        val code = constanteDeRoute(route) ?: return false
        val connexion = CallkitConnection.find(callId)
        if (connexion == null) {
            Log.d(TAG, "aucune connexion Telecom pour $callId — repli WebRTC")
            return false
        }
        return try {
            connexion.setAudioRoute(code)
            Log.i(TAG, "route demandée $route pour $callId")
            true
        } catch (e: Exception) {
            // Connexion détruite entre la recherche et la demande : cela se lit
            // comme une absence de connexion, pas comme une erreur.
            Log.w(TAG, "setAudioRoute($route) a échoué pour $callId: ${e.message}")
            false
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun lire(callId: String): Map<String, Any?>? {
        val connexion = CallkitConnection.find(callId) ?: return null
        val etat = try {
            connexion.callAudioState
        } catch (e: Exception) {
            Log.w(TAG, "lecture de l'état audio impossible pour $callId: ${e.message}")
            null
        } ?: return null
        return mapOf(
            "route" to nomDeRoute(etat.route),
            // Masque des sorties que Telecom déclare atteignables : plus sûr que
            // l'énumération des périphériques, qui n'annonce pas toujours
            // l'écouteur interne.
            "available" to etat.supportedRouteMask,
        )
    }

    /**
     * Jamais `ROUTE_WIRED_OR_EARPIECE` : cette valeur groupée est exactement
     * l'ambiguïté « écouteur ou filaire » qui renvoyait le son au mauvais
     * appareil. Chaque sortie se demande par son nom.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    private fun constanteDeRoute(route: String): Int? = when (route) {
        "earpiece" -> CallAudioState.ROUTE_EARPIECE
        "speaker" -> CallAudioState.ROUTE_SPEAKER
        "wired" -> CallAudioState.ROUTE_WIRED_HEADSET
        "bluetooth" -> CallAudioState.ROUTE_BLUETOOTH
        else -> null
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun nomDeRoute(code: Int): String? = when (code) {
        CallAudioState.ROUTE_EARPIECE -> "earpiece"
        CallAudioState.ROUTE_SPEAKER -> "speaker"
        CallAudioState.ROUTE_WIRED_HEADSET -> "wired"
        CallAudioState.ROUTE_BLUETOOTH -> "bluetooth"
        else -> null
    }
}
