package com.alanya237.alanya

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitConstants
import com.hiennv.flutter_callkit_incoming.getDataActiveCalls
import com.hiennv.flutter_callkit_incoming.widgets.RippleRelativeLayout

/**
 * Tap sur la notification d'un appel vidéo à deux, téléphone déverrouillé :
 * ouvrir l'application plutôt que l'écran natif du plugin.
 *
 * ## Pourquoi
 *
 * Le corps de la notification CallKit pointe vers `CallkitIncomingActivity`
 * (`getActivityPendingIntent` du plugin, sans option pour en changer). Cet écran
 * n'est qu'une réplique XML de `IncomingCallScreen` : pas de Flutter, donc pas
 * de caméra. Application ouverte, l'appelé se voit en fond et peut couper sa
 * caméra avant de décrocher ; depuis la notification, il tombait sur un fond
 * uni sans aperçu ni bouton caméra.
 *
 * Côté Dart, tout était prêt : `prepareIncomingFromCallKit` est documenté pour
 * « le corps de la notif tapé », et `resumeForegroundIncoming` bascule l'entrant
 * de CallKit vers Flutter dès que l'application revient au premier plan. Mais
 * l'écran natif s'ouvre dans sa propre tâche : `MainActivity` ne reprenait
 * jamais, et la bascule ne se produisait pas.
 *
 * ## Ce que fait cette classe
 *
 * À la création de `CallkitIncomingActivity`, si toutes les conditions de
 * [doitOuvrirApp] sont réunies, elle lance `MainActivity` et ferme l'écran natif
 * avant qu'il ne s'affiche (`finish` pendant `onCreate` : ni `onStart`, ni
 * `onResume`). La sonnerie native continue jusqu'à ce que Flutter reprenne la
 * main, sans trou ; l'entrée CallKit est retirée par la bascule habituelle,
 * comme un retrait programmatique — jamais comme un refus.
 *
 * ## Ce qu'elle ne fait pas
 *
 * Téléphone verrouillé ou écran éteint, l'écran natif reste : c'est lui qui sait
 * s'afficher par-dessus le verrouillage et allumer l'écran (intention plein
 * écran). Groupes, conférences et appels audio gardent aussi l'écran natif :
 * la caméra de sonnerie n'existe que pour l'appel vidéo à deux
 * (`shouldOpenCameraWhileRinging`), et rien ne justifierait d'y payer un
 * démarrage de Flutter.
 */
object IncomingVideoRedirect : Application.ActivityLifecycleCallbacks {

    private const val TAG = "IncomingVideoRedirect"

    private const val ECRAN_NATIF =
        "com.hiennv.flutter_callkit_incoming.CallkitIncomingActivity"

    /** Action de l'intent qui ouvre l'application ; lue par personne, journal seul. */
    const val ACTION_OUVRIR_ENTRANT = "com.alanya237.alanya.OUVRIR_APPEL_ENTRANT"

    fun register(app: Application) {
        app.registerActivityLifecycleCallbacks(this)
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        if (activity.javaClass.name != ECRAN_NATIF) return
        val data = try {
            activity.intent?.extras?.getBundle(
                CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA,
            )
        } catch (e: Exception) {
            Log.w(TAG, "données de l'écran natif illisibles: $e")
            null
        } ?: return
        if (!doitOuvrirApp(activity, data)) return

        try {
            activity.startActivity(
                Intent(activity, MainActivity::class.java).apply {
                    action = ACTION_OUVRIR_ENTRANT
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        } catch (e: Exception) {
            // L'écran natif reste : l'appel se décroche comme avant.
            Log.e(TAG, "ouverture de l'application échouée — écran natif conservé", e)
            return
        }
        Log.i(TAG, "appel vidéo : application ouverte à la place de l'écran natif")
        activity.finishAndRemoveTask()
    }

    /**
     * Toutes les conditions, dans l'ordre où elles écartent le plus de cas.
     *
     * Chacune laisse l'écran natif en place quand elle échoue : c'est le
     * comportement d'avant, qui fonctionne.
     */
    private fun doitOuvrirApp(context: Context, data: Bundle): Boolean {
        // Appel vidéo uniquement (type 1, posé par Dart comme par le natif).
        if (data.getInt(CallkitConstants.EXTRA_CALLKIT_TYPE, 0) <= 0) return false

        // À deux uniquement : un salon ou une session désigne un groupe ou une
        // conférence, qui n'ouvrent pas la caméra pendant la sonnerie.
        @Suppress("DEPRECATION", "UNCHECKED_CAST")
        val extra = try {
            data.getSerializable(CallkitConstants.EXTRA_CALLKIT_EXTRA) as? Map<String, Any?>
        } catch (e: Exception) {
            null
        } ?: return false
        val roomId = extra["roomId"]?.toString()?.trim().orEmpty()
        val sessionKind = extra["sessionKind"]?.toString()?.trim().orEmpty()
        if (roomId.isNotEmpty() || sessionKind == "conference") return false

        // Téléphone en main : écran allumé et déverrouillé.
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (power?.isInteractive != true) return false
        if (keyguard == null || keyguard.isKeyguardLocked) return false

        // Sans permission caméra, l'écran Flutter n'aurait rien de plus à
        // montrer (la sonnerie ne la demande jamais).
        if (context.checkSelfPermission(Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        // L'appel sonne-t-il encore ? Une notification restée affichée après la
        // fin de l'appel ne doit pas ouvrir l'application sur un entrant mort.
        val id = data.getString(CallkitConstants.EXTRA_CALLKIT_ID, "")?.trim().orEmpty()
        if (id.isEmpty()) return false
        val sonneEncore = try {
            getDataActiveCalls(context.applicationContext)
                .any { it.id == id && !it.isAccepted }
        } catch (e: Exception) {
            Log.w(TAG, "lecture ACTIVE_CALLS: $e")
            false
        }
        return sonneEncore
    }

    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivityResumed(activity: Activity) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
    /**
     * Arrête l'animation d'ondes de l'écran natif à sa fermeture.
     *
     * Le plugin la lance dans `onCreate` (animateurs en répétition infinie) et
     * ne l'arrête jamais : elle survivait à l'écran, retenue par le
     * gestionnaire d'animations du processus, et demandait des images à
     * l'infini. Vrai de tout écran natif fermé, et a fortiori de celui qu'on
     * ferme avant même qu'il ne s'affiche.
     */
    override fun onActivityDestroyed(activity: Activity) {
        if (activity.javaClass.name != ECRAN_NATIF) return
        try {
            activity.findViewById<RippleRelativeLayout>(
                com.hiennv.flutter_callkit_incoming.R.id.llBackgroundAnimation,
            )?.stopRippleAnimation()
        } catch (e: Exception) {
            Log.w(TAG, "arrêt de l'animation de l'écran natif: $e")
        }
    }
}
