package com.alanya237.alanya

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val EXTRA_NOTIFICATION_OPEN = "talky_notification_open"
        private const val TAG = "TalkyMainActivity"
        private const val NOTIFICATION_OPEN_CHANNEL = "com.alanya/notification_open"
    }

    private val mediaExportChannel = "com.alanya/media_export"
    private val callPermissionsChannel = "com.alanya/call_permissions"
    private val deviceIdentityChannel = "com.alanya/device_identity"

    private var notificationOpenChannel: MethodChannel? = null
    private var pendingNotificationOpen: Map<String, String>? = null
    /** True une fois que Dart a appelé getInitialOpen (handler onOpen prêt). */
    private var flutterNotificationOpenReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Permet à l'écran d'appel d'apparaître par-dessus l'écran de verrouillage
        // et de réveiller l'écran quand un appel entrant arrive (CallKit/FCM).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // L'app passe au premier plan : Flutter (RingtoneService) reprend la
        // sonnerie entrante via le socket. On coupe la sonnerie importée jouée
        // nativement pour éviter le doublon (voir CustomRingtonePlayer).
        CustomRingtonePlayer.stop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaExportChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        try {
                            val path = call.argument<String>("path")
                            val fileName = call.argument<String>("fileName")
                            val mimeType = call.argument<String>("mimeType")
                                ?: "application/octet-stream"
                            val subdir = call.argument<String>("subdir") ?: "Alanya"
                            if (path.isNullOrBlank() || fileName.isNullOrBlank()) {
                                result.error("bad_args", "path/fileName requis", null)
                                return@setMethodCallHandler
                            }
                            val saved = saveToDownloads(path, fileName, mimeType, subdir)
                            if (saved) result.success(true)
                            else result.error("save_failed", "Échec copie Downloads", null)
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callPermissionsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val nm = getSystemService(NotificationManager::class.java)
                            result.success(nm.canUseFullScreenIntent())
                        } else {
                            result.success(true)
                        }
                    }
                    // TalkyFirebaseMessagingService décide d'afficher CallKit sur
                    // le critère keyguard + importance ; Dart ne connaissait que
                    // le cycle de vie Flutter. Écran verrouillé avec l'app encore
                    // résumée, les deux revendiquaient chacun leur UI entrante :
                    // deux écrans et deux sonneries. Ce canal aligne Dart sur le
                    // même critère que le natif.
                    "isKeyguardLocked" -> {
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                        result.success(km?.isKeyguardLocked ?: false)
                    }
                    "openFullScreenIntentSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                Uri.parse("package:$packageName"),
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Identifiant matériel pour la table `appareils` (révocation de session).
        // ANDROID_ID et non Build.ID : Build.ID est l'empreinte du firmware, donc
        // identique sur tous les téléphones d'un même modèle et modifiée à chaque
        // mise à jour système — inutilisable comme clé d'appareil. ANDROID_ID est
        // unique par (appareil, signature d'app, utilisateur) et survit à une
        // réinstallation. device_info_plus ne l'expose plus depuis sa v9, d'où ce
        // canal natif.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceIdentityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidId" -> {
                        try {
                            val id = Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID,
                            )
                            result.success(if (id.isNullOrBlank()) null else id)
                        } catch (e: Exception) {
                            Log.w(TAG, "ANDROID_ID indisponible: ${e.message}")
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        CallNativeBridge.attach(flutterEngine.dartExecutor.binaryMessenger, this)
        CallMediaBridge.attach(flutterEngine.dartExecutor.binaryMessenger, this)

        notificationOpenChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_OPEN_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialOpen" -> {
                        flutterNotificationOpenReady = true
                        result.success(pendingNotificationOpen)
                        pendingNotificationOpen = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * Tap sur notif MessagingStyle native : extras → Flutter (PushService).
     * Cold start : stocké jusqu'à getInitialOpen.
     * App déjà vivante (handler prêt) : push immédiat via onOpen.
     */
    private fun handleNotificationIntent(intent: Intent?) {
        if (intent == null) return
        val isOpen = intent.getBooleanExtra(EXTRA_NOTIFICATION_OPEN, false)
        val convId = intent.getIntExtra(MessageNotificationHelper.EXTRA_CONVERSATION_ID, 0)
            .takeIf { it > 0 }
            ?: intent.getStringExtra(MessageNotificationHelper.EXTRA_CONVERSATION_ID)
                ?.toIntOrNull()
            ?: 0
        if (!isOpen && convId <= 0) return
        if (convId <= 0) return

        val payload = linkedMapOf(
            "type" to (intent.getStringExtra("type") ?: "message"),
            "conversationId" to convId.toString(),
        )
        for (key in listOf(
            "title",
            "senderName",
            "isGroup",
            "groupName",
            "msgID",
            "senderId",
        )) {
            intent.getStringExtra(key)?.let { payload[key] = it }
        }

        // Évite de rejouer le même Intent (rotation / recreate).
        intent.removeExtra(EXTRA_NOTIFICATION_OPEN)
        intent.removeExtra(MessageNotificationHelper.EXTRA_CONVERSATION_ID)

        Log.d(TAG, "notification open conv=$convId ready=$flutterNotificationOpenReady")
        if (flutterNotificationOpenReady) {
            notificationOpenChannel?.invokeMethod("onOpen", payload)
        } else {
            pendingNotificationOpen = payload
        }
    }

    private fun saveToDownloads(
        srcPath: String,
        fileName: String,
        mimeType: String,
        subdir: String,
    ): Boolean {
        val src = File(srcPath)
        if (!src.exists() || !src.isFile) return false

        // subdir peut être imbriqué : "Alanya/Alanya Images"
        val relative = Environment.DIRECTORY_DOWNLOADS + "/" +
            subdir.trim('/').replace('\\', '/')

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, relative)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return false
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { input -> input.copyTo(out) }
            } ?: return false
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return true
        }

        @Suppress("DEPRECATION")
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            subdir.trim('/').replace('\\', '/'),
        )
        if (!dir.exists() && !dir.mkdirs()) return false
        val dest = File(dir, fileName)
        src.copyTo(dest, overwrite = true)
        return true
    }
}
