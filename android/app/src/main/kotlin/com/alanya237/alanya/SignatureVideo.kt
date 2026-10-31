package com.alanya237.alanya

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max
import kotlin.math.min

/**
 * LA SIGNATURE INCRUSTÉE AUX QUATRE BORDS D'UNE VIDÉO SENSIBLE (reprise
 * d'Alanya Work ; plan : PLAN-DOCUMENTS-SENSIBLES.md), méthode `signerVideo`
 * du canal `alanya/signature`.
 *
 * Comme pour une photo, le texte de la signature court aux quatre bords de la
 * copie enregistrée. Il survit à un renvoi par une messagerie qui réencode la
 * vidéo et efface ses métadonnées.
 *
 * Media3 Transformer (la version que `pro_video_editor` impose déjà à l'app)
 * décode la vidéo, pose sur chaque image un CALQUE transparent où les bords
 * sont peints une fois pour toutes (`BitmapOverlay`), et réencode en H.264 /
 * AAC. La rotation d'origine est appliquée avant les effets : le calque est
 * donc fait aux dimensions À L'ÉCRAN, que `Presentation` fixe.
 *
 * Les métadonnées (empreinte et champs) sont écrites ensuite, en Dart, sur le
 * MP4 produit (`mp4_metadonnees.dart`). Un échec ici remonte à Dart, qui
 * retombe sur la copie aux seules métadonnées : jamais pire qu'avant.
 *
 * `@OptIn(UnstableApi::class)` : les effets de Media3 sont marqués instables,
 * et le contrôle d'Android (lint) refuse sinon la construction.
 */
@OptIn(UnstableApi::class)
class SignatureVideo(private val contexte: Context) {

    private companion object {
        const val TAG = "AlanyaSignatureVideo"
    }

    /** Transformer veut un fil qui a une boucle de messages : le fil principal. */
    private val principal = Handler(Looper.getMainLooper())

    fun traiter(appel: MethodCall, resultat: MethodChannel.Result) {
        if (appel.method != "signerVideo") {
            resultat.notImplemented()
            return
        }
        val entree = appel.argument<String>("entree")
        val sortie = appel.argument<String>("sortie")
        val bords = appel.argument<String>("bords") ?: ""
        if (entree == null || sortie == null) {
            resultat.error("ARGUMENTS", "entree et sortie sont obligatoires", null)
            return
        }
        principal.post { demarrer(entree, sortie, bords, resultat) }
    }

    private fun demarrer(entree: String, sortie: String, texte: String, resultat: MethodChannel.Result) {
        try {
            val (l, h) = dimensionsEcran(entree)
            val calque = Bitmap.createBitmap(l, h, Bitmap.Config.ARGB_8888)
            peindreBords(Canvas(calque), l.toFloat(), h.toFloat(), texte)
            val effets = Effects(
                emptyList(),
                listOf(
                    Presentation.createForWidthAndHeight(l, h, Presentation.LAYOUT_SCALE_TO_FIT),
                    // Type explicite : la liste Java attendue est invariante.
                    OverlayEffect(
                        ImmutableList.of<TextureOverlay>(BitmapOverlay.createStaticBitmapOverlay(calque)),
                    ),
                ),
            )
            val element = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(entree))))
                .setEffects(effets)
                .build()
            Transformer.Builder(contexte)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        calque.recycle()
                        resultat.success(mapOf("chemin" to sortie, "mime" to "video/mp4"))
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        calque.recycle()
                        File(sortie).delete()
                        Log.w(TAG, "Vidéo non signée : ${exportException.message}")
                        resultat.error("ECHEC", exportException.message, null)
                    }
                })
                .build()
                .start(element, sortie)
        } catch (e: Throwable) {
            Log.w(TAG, "Vidéo non signée : ${e.message}")
            resultat.error("ECHEC", e.message, null)
        }
    }

    /** Largeur et hauteur À L'ÉCRAN (rotation comprise), paires pour l'encodeur. */
    private fun dimensionsEcran(chemin: String): Pair<Int, Int> {
        val lecteur = MediaMetadataRetriever()
        try {
            lecteur.setDataSource(chemin)
            val l = lecteur.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val h = lecteur.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            val rotation = lecteur.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            if (l == null || h == null || l < 16 || h < 16) {
                throw IllegalArgumentException("Vidéo sans dimensions lisibles")
            }
            val couchee = rotation % 180 != 0
            val ecranL = if (couchee) h else l
            val ecranH = if (couchee) l else h
            return Pair(ecranL - ecranL % 2, ecranH - ecranH % 2)
        } finally {
            lecteur.release()
        }
    }

    /**
     * Un champ par bord — haut, bas, gauche, droite, séparés par « \n » —,
     * en blanc cerné de noir, 16 px au moins : la compression d'une
     * messagerie bave sur les couleurs, pas sur un fort contraste.
     */
    private fun peindreBords(toile: Canvas, l: Float, h: Float, texte: String) {
        val lignes = texte.split('\n')
        val (haut, bas, gauche, droite) = if (lignes.size == 4) lignes else List(4) { texte }
        val base = max(16f, min(l, h) / 50f)
        val remplissage = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(240, 255, 255, 255)
            typeface = Typeface.DEFAULT_BOLD
            textSize = base
        }
        val contour = Paint(remplissage).apply {
            style = Paint.Style.STROKE
            strokeJoin = Paint.Join.ROUND
            color = Color.argb(230, 0, 0, 0)
        }
        val marge = base * 0.6f
        // La bande du texte perpendiculaire : sa marge, plus sa hauteur de ligne.
        val coin = marge + base * 1.3f

        // Réduite seulement si la ligne ne tient pas sur son bord.
        fun taillePour(ligne: String, longueur: Float): Float {
            remplissage.textSize = base
            val unite = remplissage.measureText(ligne) / base
            return if (unite <= 0f) base else min(base, (longueur - 2 * coin) / unite)
        }

        fun bord(ligne: String, cx: Float, cy: Float, angle: Float, taille: Float) {
            if (ligne.isBlank()) return
            remplissage.textSize = taille
            contour.textSize = taille
            contour.strokeWidth = taille * 0.22f
            val largeur = remplissage.measureText(ligne)
            val m = remplissage.fontMetrics
            val y = -(m.ascent + m.descent) / 2
            toile.save()
            toile.translate(cx, cy)
            toile.rotate(angle)
            toile.drawText(ligne, -largeur / 2, y, contour)
            toile.drawText(ligne, -largeur / 2, y, remplissage)
            toile.restore()
        }

        val tHaut = taillePour(haut, l)
        val tBas = taillePour(bas, l)
        val tGauche = taillePour(gauche, h)
        val tDroite = taillePour(droite, h)
        bord(haut, l / 2, marge + tHaut * 0.6f, 0f, tHaut)
        bord(bas, l / 2, h - marge - tBas * 0.6f, 0f, tBas)
        // Gauche : lu de bas en haut. Droite : lu de haut en bas.
        bord(gauche, marge + tGauche * 0.6f, h / 2, -90f, tGauche)
        bord(droite, l - marge - tDroite * 0.6f, h / 2, 90f, tDroite)
    }
}
