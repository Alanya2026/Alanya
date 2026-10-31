package com.alanya237.alanya

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Compression des vidéos avant envoi, par Media3 Transformer.
 * Canal : `com.alanya237.alanya/video_transcode`.
 *
 * - `capabilities` : le téléphone sait-il encoder et lire le HEVC en 720p, par
 *   une puce dédiée ? Le logiciel ne compte pas : trop lent pour encoder, trop
 *   gourmand pour lire sur un téléphone modeste.
 * - `probe` : ce qu'on sait d'une vidéo (codec, dimensions, durée, débit,
 *   images par seconde, HDR).
 * - `transcode` : réduction au côté court de 720 px, plafond d'images par
 *   seconde, débit fixé, H.264 ou HEVC, son AAC, HDR ramené en SDR. La
 *   progression remonte par `progress` ({id, progress 0..1}).
 * - `cancel` : interrompt une conversion en cours.
 *
 * Transformer exige un thread à Looper : tout se passe sur le thread principal,
 * celui du canal. Le travail lourd, lui, est fait par les codecs matériels.
 */
object VideoTranscodeBridge {
    private const val TAG = "VideoTranscode"
    private const val CHANNEL = "com.alanya237.alanya/video_transcode"
    private const val PROGRESS_INTERVAL_MS = 400L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val running = mutableMapOf<String, Transformer>()
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger, context: Context) {
        val appCtx = context.applicationContext
        val ch = MethodChannel(messenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(capabilities())
                "probe" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path manquant", null)
                    } else {
                        try {
                            result.success(probe(path))
                        } catch (e: Exception) {
                            Log.w(TAG, "probe impossible: ${e.message}")
                            result.success(null)
                        }
                    }
                }
                "transcode" -> transcode(appCtx, call.arguments as? Map<*, *>, result)
                "cancel" -> {
                    val id = call.argument<String>("id")
                    running.remove(id)?.cancel()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Capacités ──────────────────────────────────────────────────────────

    private fun capabilities(): Map<String, Any> = mapOf(
        "hevcEncoder" to hasHardwareCodec(MimeTypes.VIDEO_H265, encoder = true),
        "hevcDecoder" to hasHardwareCodec(MimeTypes.VIDEO_H265, encoder = false),
        "sdk" to Build.VERSION.SDK_INT,
    )

    /**
     * Un codec matériel capable du 720p à 30 images/s, en portrait comme en
     * paysage. L'encodeur exige Android 10 : avant, rien ne distingue une
     * puce d'un encodeur logiciel. Pour la lecture, on se rabat sur le nom
     * (les décodeurs logiciels d'Android sont `OMX.google.*` et `c2.android.*`).
     */
    private fun hasHardwareCodec(mime: String, encoder: Boolean): Boolean {
        if (encoder && Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return try {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
                if (info.isEncoder != encoder) return@any false
                if (info.supportedTypes.none { it.equals(mime, ignoreCase = true) }) return@any false
                if (!isHardware(info)) return@any false
                val video = info.getCapabilitiesForType(mime).videoCapabilities ?: return@any false
                video.areSizeAndRateSupported(1280, 720, 30.0) ||
                    video.areSizeAndRateSupported(720, 1280, 30.0)
            }
        } catch (e: Exception) {
            Log.w(TAG, "liste des codecs illisible: ${e.message}")
            false
        }
    }

    private fun isHardware(info: MediaCodecInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return info.isHardwareAccelerated && !info.isSoftwareOnly
        }
        val name = info.name.lowercase()
        return !name.startsWith("omx.google.") && !name.startsWith("c2.android.")
    }

    // ── Métadonnées ───────────────────────────────────────────────────────

    private fun probe(path: String): Map<String, Any?> {
        val out = mutableMapOf<String, Any?>("sizeBytes" to File(path).length())
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            fun meta(key: Int) = retriever.extractMetadata(key)
            out["width"] = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            out["height"] = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            out["rotation"] = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull()
            out["durationMs"] = meta(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            out["bitrate"] = meta(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull()
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/")) continue
                out["videoMime"] = mime
                if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                    out["frameRate"] = try {
                        format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
                    } catch (_: ClassCastException) {
                        format.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
                    }
                }
                if (format.containsKey(MediaFormat.KEY_COLOR_TRANSFER)) {
                    val transfer = format.getInteger(MediaFormat.KEY_COLOR_TRANSFER)
                    out["hdr"] = transfer == MediaFormat.COLOR_TRANSFER_ST2084 ||
                        transfer == MediaFormat.COLOR_TRANSFER_HLG
                }
                break
            }
        } finally {
            try { extractor.release() } catch (_: Exception) {}
        }
        return out
    }

    // ── Conversion ────────────────────────────────────────────────────────

    private fun transcode(context: Context, args: Map<*, *>?, result: MethodChannel.Result) {
        val id = args?.get("id") as? String
        val input = args?.get("input") as? String
        val output = args?.get("output") as? String
        if (id == null || input == null || output == null) {
            result.error("bad_args", "id, input et output sont requis", null)
            return
        }
        val videoMime = args["videoMime"] as? String ?: MimeTypes.VIDEO_H264
        val videoBitrate = (args["videoBitrate"] as? Number)?.toInt() ?: 2_000_000
        val audioBitrate = (args["audioBitrate"] as? Number)?.toInt() ?: 64_000
        val maxShortSide = (args["maxShortSide"] as? Number)?.toInt() ?: 720
        val maxFrameRate = (args["maxFrameRate"] as? Number)?.toFloat() ?: 30f
        val iFrameSeconds = (args["iFrameIntervalSeconds"] as? Number)?.toFloat() ?: 3f

        val facts = try { probe(input) } catch (_: Exception) { emptyMap<String, Any?>() }
        val effects = mutableListOf<Effect>()
        val w = facts["width"] as? Int
        val h = facts["height"] as? Int
        if (w != null && h != null && w > 0 && h > 0) {
            // Dimensions à l'écran (une vidéo tournée de 90° a largeur et hauteur inversées).
            val tournee = (facts["rotation"] as? Int ?: 0) % 180 != 0
            val (ew, eh) = if (tournee) h to w else w to h
            // Jamais d'agrandissement : seule une vidéo plus grande est réduite.
            val echelle = minOf(1.0, maxShortSide.toDouble() / minOf(ew, eh))
            // Multiples de 16 : l'encodeur H.265 du Galaxy S10 refuse une vidéo
            // de 886 × 480 (ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED) et la
            // compression était alors abandonnée. 886 devient 880, sans effet visible.
            val cw = maxOf(16, (ew * echelle).toInt() / 16 * 16)
            val ch = maxOf(16, (eh * echelle).toInt() / 16 * 16)
            if (cw != ew || ch != eh) {
                effects += Presentation.createForWidthAndHeight(cw, ch, Presentation.LAYOUT_STRETCH_TO_FIT)
            }
        }
        val fps = facts["frameRate"] as? Double
        if (fps != null && fps > maxFrameRate + 0.5) {
            effects += FrameDropEffect.createDefaultFrameDropEffect(maxFrameRate)
        }

        File(output).parentFile?.mkdirs()
        var answered = false
        fun finish(block: () -> Unit) {
            if (answered) return
            answered = true
            running.remove(id)
            block()
        }

        val transformer = try {
            Transformer.Builder(context)
                .setVideoMimeType(videoMime)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(
                    DefaultEncoderFactory.Builder(context)
                        .setRequestedVideoEncoderSettings(
                            VideoEncoderSettings.Builder()
                                .setBitrate(videoBitrate)
                                // Débit CONSTANT, et non variable : en VBR, Android 12+
                                // impose un plancher de qualité (0,075 bit/pixel, +20 %
                                // si la puce n'accepte pas de bornes de QP), soit
                                // 2,49 Mbit/s en 720p30 quelle que soit la consigne
                                // (« VQApply: raise bitrate … to floor » dans logcat,
                                // mesuré sur un Galaxy S10). Le CBR y échappe : la
                                // consigne est tenue, le HEVC garde son avantage.
                                .setBitrateMode(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
                                .setiFrameIntervalSeconds(iFrameSeconds)
                                // Profil et niveau fixés : sinon Media3 reprend ceux de la
                                // vidéo d'origine (« avc1.64001E », niveau 3.0, trop bas
                                // pour 848 × 480 à 30 i/s, et absurde pour du H.265), et
                                // l'encodeur refuse (ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED,
                                // Galaxy S10, 31/10/2026). Le niveau 4.1 couvre le 1080p.
                                .apply {
                                    if (videoMime == MimeTypes.VIDEO_H265) {
                                        setEncodingProfileLevel(
                                            MediaCodecInfo.CodecProfileLevel.HEVCProfileMain,
                                            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel41,
                                        )
                                    } else {
                                        setEncodingProfileLevel(
                                            MediaCodecInfo.CodecProfileLevel.AVCProfileHigh,
                                            MediaCodecInfo.CodecProfileLevel.AVCLevel41,
                                        )
                                    }
                                }
                                .build()
                        )
                        .setRequestedAudioEncoderSettings(
                            AudioEncoderSettings.Builder().setBitrate(audioBitrate).build()
                        )
                        // Encodeur incapable du réglage demandé (HEVC absent,
                        // débit variable refusé…) : Media3 prend le plus proche
                        // qu'il sait faire plutôt que d'échouer.
                        .setEnableFallback(true)
                        .build()
                )
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        finish {
                            result.success(
                                mapOf(
                                    "path" to output,
                                    "videoMime" to exportResult.videoMimeType,
                                    "width" to exportResult.width,
                                    "height" to exportResult.height,
                                    "averageVideoBitrate" to exportResult.averageVideoBitrate,
                                    "durationMs" to exportResult.approximateDurationMs,
                                    "fileSizeBytes" to exportResult.fileSizeBytes,
                                )
                            )
                        }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        Log.w(TAG, "conversion échouée (${exportException.errorCodeName}): ${exportException.message}")
                        // L'encodeur H.265 refuse : un second essai en H.264, que
                        // tous les téléphones savent faire.
                        if (videoMime == MimeTypes.VIDEO_H265 && !answered) {
                            running.remove(id)
                            File(output).delete()
                            answered = true
                            val enH264 = mutableMapOf<Any?, Any?>()
                            args?.forEach { (k, v) -> enH264[k] = v }
                            enH264["videoMime"] = MimeTypes.VIDEO_H264
                            mainHandler.post { transcode(context, enH264, result) }
                            return
                        }
                        finish { result.error("transcode_failed", exportException.errorCodeName, null) }
                    }
                })
                .build()
        } catch (e: Exception) {
            Log.w(TAG, "Transformer indisponible: ${e.message}")
            result.error("transcode_unavailable", e.message, null)
            return
        }

        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(emptyList(), effects))
            .build()
        // Une vidéo HDR (téléphones récents) ressortirait aux couleurs délavées
        // sur un écran SDR : elle est ramenée en SDR. Sans effet sur une vidéo
        // SDR.
        // Constructeur obsolète mais voulu : son remplaçant exige de déclarer
        // d'avance les pistes de la séquence (son, image), et une vidéo sans
        // son ne s'y conformerait pas. Celui-ci les déduit du fichier.
        @Suppress("DEPRECATION")
        val sequence = EditedMediaItemSequence.Builder(item).build()
        val composition = Composition.Builder(sequence)
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()

        running[id] = transformer
        try {
            transformer.start(composition, output)
        } catch (e: Exception) {
            Log.w(TAG, "démarrage impossible: ${e.message}")
            finish { result.error("transcode_failed", e.message, null) }
            return
        }
        pollProgress(id, transformer)
    }

    private fun pollProgress(id: String, transformer: Transformer) {
        val holder = ProgressHolder()
        val tick = object : Runnable {
            override fun run() {
                if (running[id] !== transformer) return
                if (transformer.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel?.invokeMethod(
                        "progress",
                        mapOf("id" to id, "progress" to holder.progress / 100.0),
                    )
                }
                mainHandler.postDelayed(this, PROGRESS_INTERVAL_MS)
            }
        }
        mainHandler.postDelayed(tick, PROGRESS_INTERVAL_MS)
    }
}
