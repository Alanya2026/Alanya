package com.alanya237.alanya

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.ContentUris
import android.os.Environment
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Sauvegarde automatique du coffre-fort (lot 10) : les dossiers de documents
 * choisis par l'inscrit (choix « b » du 24/10/2026).
 *
 * Depuis Android 11, aucune autorisation simple ne donne accès aux PDF du
 * téléphone : l'inscrit choisit un dossier dans le sélecteur du système
 * (ACTION_OPEN_DOCUMENT_TREE), et l'application garde le droit de le lire
 * (takePersistableUriPermission), même après un redémarrage. Android refuse
 * de proposer la racine de Téléchargements : l'écran d'activation le dit.
 *
 * Canal `com.alanya/safebox_documents` :
 *  - pickFolder → { uri, name } ou null ;
 *  - list { uri, sinceMs } → [{ uri, name, size, modified, mime }] (sous-dossiers compris) ;
 *  - copy { uri, path } → true : copie le document pour l'envoyer ;
 *  - release { uri } : l'inscrit retire le dossier ;
 *  - storage → { free, total } : la mémoire du téléphone (« Libérer la mémoire ») ;
 *  - pickFiles { mimeTypes } → [{ uri, name, size, path?, mediaId? }] : des fichiers à
 *    ajouter au coffre (31/10/2026). `path` : l'original, lisible tel quel
 *    (photo, vidéo ou audio autorisés par la galerie) — rien n'est copié ;
 *    sans lui, l'application le copie par `copy`. Le sélecteur de
 *    file_picker recopiait tout fichier choisi (568 Mo : 12 s d'attente, et
 *    la copie restait dans le cache). `mediaId` : le numéro de la photo ou
 *    vidéo dans la galerie d'Android, pour l'envoyer à la corbeille une fois
 *    dans le coffre si l'inscrit le veut (07/11/2026).
 *
 * Les listes et copies tournent hors du fil principal.
 */
class SafeboxDocumentFolders(private val activity: FragmentActivity) {
    companion object {
        private const val TAG = "SafeboxDocuments"
        const val CHANNEL = "com.alanya/safebox_documents"
        private const val PROFONDEUR_MAX = 6
        private const val FICHIERS_MAX = 5000
    }

    private val travail = Executors.newSingleThreadExecutor()
    private var enAttente: MethodChannel.Result? = null
    private var fichiersEnAttente: MethodChannel.Result? = null

    // Enregistrés dans onCreate : un lanceur doit l'être avant que l'activité démarre.
    private val choix: ActivityResultLauncher<Uri?> =
        activity.registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri -> choisi(uri) }
    private val choixFichiers: ActivityResultLauncher<Array<String>> =
        activity.registerForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris -> fichiersChoisis(uris) }

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFolder" -> {
                    if (enAttente != null) {
                        result.error("busy", "Un choix de dossier est déjà ouvert", null)
                    } else {
                        enAttente = result
                        try {
                            choix.launch(null)
                        } catch (e: Exception) {
                            enAttente = null
                            result.error("pick_failed", e.message, null)
                        }
                    }
                }
                "pickFiles" -> {
                    if (fichiersEnAttente != null) {
                        result.error("busy", "Un choix de fichiers est déjà ouvert", null)
                    } else {
                        val types = call.argument<List<String>>("mimeTypes")?.takeIf { it.isNotEmpty() } ?: listOf("*/*")
                        fichiersEnAttente = result
                        try {
                            choixFichiers.launch(types.toTypedArray())
                        } catch (e: Exception) {
                            fichiersEnAttente = null
                            result.error("pick_failed", e.message, null)
                        }
                    }
                }
                "list" -> {
                    val uri = call.argument<String>("uri")
                    val depuis = (call.argument<Number>("sinceMs") ?: 0).toLong()
                    if (uri == null) {
                        result.error("bad_args", "uri requise", null)
                    } else {
                        enFond(result) { lister(Uri.parse(uri), depuis) }
                    }
                }
                "copy" -> {
                    val uri = call.argument<String>("uri")
                    val chemin = call.argument<String>("path")
                    if (uri == null || chemin == null) {
                        result.error("bad_args", "uri et path requis", null)
                    } else {
                        enFond(result) { copier(Uri.parse(uri), File(chemin)) }
                    }
                }
                "release" -> {
                    val uri = call.argument<String>("uri")
                    try {
                        if (uri != null) {
                            activity.contentResolver.releasePersistableUriPermission(
                                Uri.parse(uri), Intent.FLAG_GRANT_READ_URI_PERMISSION,
                            )
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "release: ${e.message}")
                    }
                    result.success(true)
                }
                "storage" -> {
                    try {
                        val stat = StatFs(Environment.getDataDirectory().path)
                        result.success(mapOf("free" to stat.availableBytes, "total" to stat.totalBytes))
                    } catch (e: Exception) {
                        result.error("statfs_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enFond(result: MethodChannel.Result, action: () -> Any?) {
        travail.execute {
            try {
                val valeur = action()
                activity.runOnUiThread { result.success(valeur) }
            } catch (e: Exception) {
                Log.w(TAG, "échec : ${e.message}")
                activity.runOnUiThread { result.error("failed", e.message, null) }
            }
        }
    }

    private fun choisi(uri: Uri?) {
        val result = enAttente ?: return
        enAttente = null
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            result.success(mapOf("uri" to uri.toString(), "name" to nomDuDossier(activity, uri)))
        } catch (e: Exception) {
            result.error("permission_failed", e.message, null)
        }
    }

    private fun fichiersChoisis(uris: List<Uri>) {
        val result = fichiersEnAttente ?: return
        fichiersEnAttente = null
        if (uris.isEmpty()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        enFond(result) { uris.map { decrire(it) } }
    }

    /** Nom, taille et, s'il se lit tel quel, le chemin de l'original. */
    private fun decrire(uri: Uri): Map<String, Any?> {
        var nom = uri.lastPathSegment?.substringAfterLast('/') ?: "fichier"
        var taille = -1L
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
            ?.use { c ->
                if (c.moveToFirst()) {
                    if (!c.isNull(0)) nom = c.getString(0)
                    if (!c.isNull(1)) taille = c.getLong(1)
                }
            }
        val chemin = try { cheminLisible(uri, taille) } catch (e: Exception) {
            Log.w(TAG, "chemin introuvable pour $uri : ${e.message}")
            null
        }
        val media = chemin?.let {
            try { numeroMedia(it) } catch (e: Exception) {
                Log.w(TAG, "numéro de galerie introuvable : ${e.message}")
                null
            }
        }
        return mapOf("uri" to uri.toString(), "name" to nom, "size" to taille, "path" to chemin, "mediaId" to media)
    }

    /** Le numéro d'une photo ou d'une vidéo dans la galerie d'Android, d'après son chemin. */
    @Suppress("DEPRECATION") // DATA : le seul lien entre un chemin et la galerie.
    private fun numeroMedia(chemin: String): String? {
        val type = "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (" +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}, ${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO})"
        activity.contentResolver.query(
            MediaStore.Files.getContentUri("external"),
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.DATA} = ? AND $type",
            arrayOf(chemin),
            null,
        )?.use { c -> if (c.moveToFirst()) return c.getLong(0).toString() }
        return null
    }

    /**
     * Le chemin du fichier sur le téléphone, s'il se lit directement (même
     * taille que le document choisi) ; sinon null, et l'application copie.
     */
    private fun cheminLisible(uri: Uri, taille: Long): String? {
        val candidat: String? = when (uri.authority) {
            // « primary:Download/Telegram/film.mkv »
            "com.android.externalstorage.documents" -> {
                val id = DocumentsContract.getDocumentId(uri)
                if (id.startsWith("primary:")) {
                    File(Environment.getExternalStorageDirectory(), id.removePrefix("primary:")).path
                } else {
                    null
                }
            }
            // « video:1234 », « image:… », « audio:… »
            "com.android.providers.media.documents" -> {
                val (genre, num) = DocumentsContract.getDocumentId(uri).split(':', limit = 2).let { it[0] to it.getOrNull(1) }
                val base = when (genre) {
                    "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    "audio" -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                    else -> null
                }
                num?.toLongOrNull()?.let { n -> base?.let { cheminMedia(ContentUris.withAppendedId(it, n)) } }
            }
            // « raw:/storage/emulated/0/Download/x.mp4 »
            "com.android.providers.downloads.documents" -> {
                val id = DocumentsContract.getDocumentId(uri)
                if (id.startsWith("raw:")) id.removePrefix("raw:") else null
            }
            MediaStore.AUTHORITY -> cheminMedia(uri)
            else -> null
        }
        val f = candidat?.let { File(it) } ?: return null
        return if (f.isFile && f.canRead() && (taille < 0 || f.length() == taille)) f.path else null
    }

    @Suppress("DEPRECATION") // DATA : le seul moyen d'obtenir le chemin d'un média.
    private fun cheminMedia(uri: Uri): String? =
        activity.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
            ?.use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null }

    private fun nomDuDossier(context: Context, arbre: Uri): String {
        val doc = DocumentsContract.buildDocumentUriUsingTree(arbre, DocumentsContract.getTreeDocumentId(arbre))
        context.contentResolver.query(doc, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) return c.getString(0) ?: "" }
        return DocumentsContract.getTreeDocumentId(arbre).substringAfterLast(':').substringAfterLast('/')
    }

    /** Les documents de l'arborescence, modifiés depuis [depuis] (ms), sous-dossiers compris. */
    private fun lister(arbre: Uri, depuis: Long): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val colonnes = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        fun parcourir(docId: String, profondeur: Int) {
            if (profondeur > PROFONDEUR_MAX || out.size >= FICHIERS_MAX) return
            val enfants = DocumentsContract.buildChildDocumentsUriUsingTree(arbre, docId)
            activity.contentResolver.query(enfants, colonnes, null, null, null)?.use { c ->
                while (c.moveToNext() && out.size < FICHIERS_MAX) {
                    val id = c.getString(0) ?: continue
                    val nom = c.getString(1) ?: continue
                    val mime = c.getString(2)
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        // Les dossiers cachés (« .thumbnails ») restent de côté.
                        if (!nom.startsWith(".")) parcourir(id, profondeur + 1)
                        continue
                    }
                    if (nom.startsWith(".")) continue
                    val modifie = if (c.isNull(4)) 0L else c.getLong(4)
                    if (modifie < depuis) continue
                    out.add(
                        mapOf(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(arbre, id).toString(),
                            "name" to nom,
                            "mime" to mime,
                            "size" to (if (c.isNull(3)) 0L else c.getLong(3)),
                            "modified" to modifie,
                        ),
                    )
                }
            }
        }
        parcourir(DocumentsContract.getTreeDocumentId(arbre), 0)
        return out
    }

    private fun copier(uri: Uri, cible: File): Boolean {
        cible.parentFile?.mkdirs()
        val entree = activity.contentResolver.openInputStream(uri) ?: return false
        entree.use { e -> cible.outputStream().use { s -> e.copyTo(s, 256 * 1024) } }
        return true
    }
}
