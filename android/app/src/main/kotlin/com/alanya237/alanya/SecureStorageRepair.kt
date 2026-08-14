package com.alanya237.alanya

import android.content.Context
import android.util.Log
import java.security.KeyStore

/**
 * Remise à zéro du magasin chiffré de flutter_secure_storage quand il est
 * devenu illisible.
 *
 * Le plugin chiffre ses valeurs avec `EncryptedSharedPreferences`, dont la clé
 * maîtresse vit dans le Keystore Android. Cette clé ne quitte jamais
 * l'appareil : restauration d'une sauvegarde, transfert d'appareil à appareil
 * ou réinitialisation du Keystore laissent un fichier de préférences chiffré
 * face à une clé absente ou incompatible.
 *
 * Le plugin bascule alors silencieusement sur son chiffrement hérité
 * (AES/CBC via javax.crypto) et chaque lecture lève
 * `BadPaddingException: BAD_DECRYPT`. Son `resetOnError` vide bien le fichier,
 * mais **pas** l'alias Keystore fautif : à chaque démarrage
 * `EncryptedSharedPreferences` échoue à nouveau et l'app reste en mode dégradé.
 *
 * On efface donc les deux : le fichier ET l'alias, pour que la prochaine
 * initialisation reparte sur une clé neuve.
 */
object SecureStorageRepair {

    private const val TAG = "TalkySecureRepair"

    /** Nom par défaut du fichier de flutter_secure_storage. */
    private const val PREFS_NAME = "FlutterSecureStorage"

    /** Alias par défaut de androidx.security.crypto.MasterKey. */
    private const val MASTER_KEY_ALIAS = "_androidx_security_master_key_"

    private const val ANDROID_KEYSTORE = "AndroidKeyStore"

    /**
     * Vide le magasin et supprime la clé maîtresse. Renvoie true si au moins
     * une des deux opérations a abouti.
     *
     * Ne détruit que des données déjà indéchiffrables : la session est perdue
     * dans tous les cas, l'utilisateur se reconnecte.
     */
    fun reset(context: Context): Boolean {
        var repaired = false

        try {
            context.applicationContext
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit()
            repaired = true
            Log.i(TAG, "préférences chiffrées vidées")
        } catch (e: Exception) {
            Log.e(TAG, "vidage des préférences échoué", e)
        }

        try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            if (keyStore.containsAlias(MASTER_KEY_ALIAS)) {
                keyStore.deleteEntry(MASTER_KEY_ALIAS)
                repaired = true
                Log.i(TAG, "clé maîtresse Keystore supprimée")
            }
        } catch (e: Exception) {
            Log.e(TAG, "suppression de la clé maîtresse échouée", e)
        }

        return repaired
    }
}
