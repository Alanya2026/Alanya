import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/qr_models.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/qr_added_sheet.dart';
import '../navigation/app_navigator.dart';
import '../theme/app_colors.dart';
import '../utils/app_log.dart';
import 'local_cache_repository.dart';

/// Ajout d'un contact par code QR, partagé entre les deux chemins qui y
/// mènent : le scan de la caméra et l'ouverture d'un lien `…/q/u/<jeton>`.
///
/// Les deux doivent se comporter identiquement — même écriture de cache, même
/// bandeau annulable — sinon l'ajout par lien deviendrait un ajout sans filet.
class QrContactFlow {
  const QrContactFlow._();

  /// Reconstruit l'URL d'identité à partir d'un jeton reçu par lien, selon son
  /// genre (`c` éphémère / `u` permanent). Le serveur reste l'autorité de
  /// résolution : on ne fait que lui redonner la forme qu'il sait lire.
  static String payloadForToken(String kind, String token) {
    final base = TalkyApiClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$base/q/$kind/$token';
  }

  /// Met le contact fraîchement ajouté dans le cache local, puis relit la
  /// liste pour que l'UI reflète l'ajout sans attendre une synchronisation.
  static Future<void> cacheContact(
    LocalCacheRepository cache,
    User user,
  ) async {
    try {
      // Payload de résolution incomplet (ni email ni pays) : écriture partielle.
      await cache.upsertKnownUser(user, preferred: true, partial: true);
      await cache.getPreferredContactsOnce();
    } catch (e, st) {
      AppLog.w('QrContact', 'Mise à jour du cache local échouée', e, st);
    }
  }

  /// Bandeau de succès, annulable 5 secondes.
  ///
  /// L'ajout par QR est instantané, sans écran de confirmation : ce bandeau est
  /// le seul filet. Il n'utilise aucun `BuildContext` après coup — l'écran qui
  /// l'a déclenché peut être démonté quand l'utilisateur appuie sur « Annuler ».
  static void showAddedSnack({
    required ScaffoldMessengerState messenger,
    required TalkyApiClient apiClient,
    required LocalCacheRepository cache,
    required AppLocalizations l10n,
    required User user,
    required bool alreadyContact,
  }) {
    final name = user.nom.trim().isNotEmpty ? user.nom.trim() : user.pseudo;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          alreadyContact
              ? l10n.qrScanAlreadyContact(name)
              : l10n.qrScanAddSuccess(name),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 5),
        // Rien à annuler si la personne était déjà un contact : la retirer
        // supprimerait un lien que ce scan n'a pas créé.
        action: alreadyContact
            ? null
            : SnackBarAction(
                label: l10n.qrScanUndo,
                textColor: AppColors.white,
                onPressed: () => _undo(messenger, apiClient, cache, l10n, user, name),
              ),
      ),
    );
  }

  /// Enregistre la note contextuelle — serveur puis miroir local. Retourne
  /// vrai en cas de succès ; l'appelant décide de l'affichage d'erreur.
  static Future<bool> saveNote({
    required TalkyApiClient apiClient,
    required LocalCacheRepository cache,
    required User user,
    required String note,
  }) async {
    try {
      await apiClient.setContactNote(user.alanyaID, note);
      await cache.setPreferredNote(user.alanyaID, note);
      return true;
    } catch (e, st) {
      AppLog.e('QrContact', 'Enregistrement de la note échoué', e, st);
      return false;
    }
  }

  /// Retire un contact ajouté par erreur. Public : la carte de résultat du
  /// scanner l'appelle aussi, avec son propre bouton d'annulation.
  static Future<void> undoAdd({
    required ScaffoldMessengerState messenger,
    required TalkyApiClient apiClient,
    required LocalCacheRepository cache,
    required AppLocalizations l10n,
    required User user,
  }) =>
      _undo(messenger, apiClient, cache, l10n, user,
          user.nom.trim().isNotEmpty ? user.nom.trim() : user.pseudo);

  static Future<void> _undo(
    ScaffoldMessengerState messenger,
    TalkyApiClient apiClient,
    LocalCacheRepository cache,
    AppLocalizations l10n,
    User user,
    String name,
  ) async {
    try {
      await cache.removePreferredContact(user.alanyaID, user: user);
      await cache.getPreferredContactsOnce();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.qrScanUndone(name)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      AppLog.e('QrContact', 'Annulation de l\'ajout par QR échouée', e, st);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.qrScanUndoFailed),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Résout un jeton reçu par lien et ajoute le contact. Retourne le résultat
  /// pour que l'appelant décide de la suite (rien à faire dans le cas nominal,
  /// le bandeau est déjà affiché).
  static Future<QrResolveResult?> handleToken({
    required String kind,
    required String token,
    required ScaffoldMessengerState messenger,
    required TalkyApiClient apiClient,
    required LocalCacheRepository cache,
    required AppLocalizations l10n,
  }) async {
    try {
      final result = await apiClient.resolveQr(payloadForToken(kind, token));

      // Un lien de connexion n'a rien à faire ici : l'approbation exige un
      // scan et un écran de confirmation, jamais un lien cliqué.
      if (!result.isContact) return result;

      if (result.isSelf) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.qrScanOwnCode),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return result;
      }

      final contact = result.contact;
      if (contact == null) return result;

      final user = User.fromJson(contact);
      await cacheContact(cache, user);

      // Feuille modale quand un Navigator est disponible : l'utilisateur
      // revient d'un navigateur et doit voir QUI a été ajouté. Le bandeau
      // reste le repli — mieux vaut un retour faible qu'aucun retour si la
      // navigation n'est pas encore montée (démarrage à froid).
      final nav = appNavigator;
      if (nav != null && nav.mounted) {
        await showQrAddedSheet(
          context: nav.context,
          user: user,
          alreadyContact: result.alreadyContact,
          onNote: result.alreadyContact
              ? null
              : (note) => saveNote(
                    apiClient: apiClient,
                    cache: cache,
                    user: user,
                    note: note,
                  ),
          onUndo: () => unawaited(undoAdd(
            messenger: messenger,
            apiClient: apiClient,
            cache: cache,
            l10n: l10n,
            user: user,
          )),
        );
      } else {
        showAddedSnack(
          messenger: messenger,
          apiClient: apiClient,
          cache: cache,
          l10n: l10n,
          user: user,
          alreadyContact: result.alreadyContact,
        );
      }
      return result;
    } on TalkyException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 404 ? l10n.qrScanErrorUnknown : e.message,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return null;
    } catch (e, st) {
      AppLog.e('QrContact', 'Résolution du lien QR échouée', e, st);
      return null;
    }
  }
}
