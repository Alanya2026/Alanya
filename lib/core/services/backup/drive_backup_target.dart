import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'backup_target.dart';
import 'local_folder_target.dart' show BackupArchiveNotFound;

/// Dépose les sauvegardes dans le Google Drive de l'inscrit.
///
/// ── Le champ d'accès, et pourquoi celui-là ──
///
/// `drive.file` limite l'application **aux fichiers qu'elle a créés**. Elle est
/// aveugle au reste du Drive : documents, photos, tout ce qui ne vient pas
/// d'elle lui est inaccessible. C'est ce qui permet d'écrire honnêtement à
/// l'inscrit « Alanya ne voit rien d'autre de votre Drive ».
///
/// C'est aussi le champ le moins exigeant côté Google : classé non sensible,
/// il ne demande qu'une vérification de base — pas la procédure lourde avec
/// justification écrite et audit de sécurité qu'imposerait l'accès complet.
///
/// ── L'hypothèse non vérifiée ──
///
/// Toute la restauration repose sur un point qui n'a pas été éprouvé : après
/// une réinstallation, l'application retrouve-t-elle les fichiers qu'elle avait
/// déposés depuis l'ancien téléphone ? Le droit « fichiers créés par
/// l'application » devrait suivre l'identifiant client OAuth, donc survivre à
/// une nouvelle installation — mais ça reste à constater.
///
/// **Si la réponse est non**, il faudra basculer sur le dossier caché
/// (`drive.appdata`), lui aussi classé non sensible. On perdra le dossier
/// visible que l'inscrit peut gérer lui-même, et rien d'autre : c'est
/// exactement ce que l'interface [BackupTarget] protège.
class DriveBackupTarget implements BackupTarget {
  /// Dossier visible dans le Drive de l'inscrit.
  ///
  /// Visible et non caché : il voit ses sauvegardes, connaît leur poids, peut
  /// les effacer pour faire de la place. Contrepartie assumée — il peut aussi
  /// les supprimer par erreur.
  static const folderName = 'Alanya';

  static const _folderMime = 'application/vnd.google-apps.folder';

  final drive.DriveApi _api;

  /// Compte Google effectivement connecté. Affiché à l'écran pour lever toute
  /// ambiguïté : il peut différer de l'adresse du compte Alanya, et l'inscrit
  /// doit pouvoir vérifier d'un coup d'œil sur quel Drive il sauvegarde.
  final String? accountEmail;

  /// Identifiant du dossier `Alanya`, résolu une fois puis mémorisé.
  String? _folderId;

  DriveBackupTarget(this._api, {this.accountEmail});

  /// Connecte le compte Google et rend une destination prête à l'emploi.
  ///
  /// Retourne `null` si l'inscrit refuse la connexion — ce n'est pas une
  /// erreur : il a le droit de dire non, et le repli local prend le relais.
  /// [accountEmail] désigne le compte à retrouver **en silence**.
  ///
  /// ── Pourquoi seulement en silence ──
  ///
  /// Le paramètre du plugin s'appelle `forceAccountName`, et il porte bien son
  /// nom : il force, il ne suggère pas. Employé sur le chemin interactif, il
  /// connectait directement le compte dont l'adresse figure sur le compte
  /// Alanya — **sans jamais ouvrir le sélecteur**. Quelqu'un dont l'adresse
  /// Alanya est professionnelle mais qui veut sauvegarder sur son Drive
  /// personnel n'avait aucun moyen de le dire.
  ///
  /// Il n'a donc sa place que là où il n'y a personne pour choisir : la
  /// sauvegarde automatique, qui doit retrouver toute seule le compte déjà
  /// autorisé. Dès qu'un écran est ouvert, c'est l'inscrit qui tranche.
  static Future<DriveBackupTarget?> connect({
    bool silent = true,
    String? accountEmail,
  }) async {
    if (!silent) return _attempt(silent: false, accountName: null);

    final hint = (accountEmail ?? '').trim();
    if (hint.isNotEmpty) {
      final withHint = await _attempt(silent: true, accountName: hint);
      if (withHint != null) return withHint;
    }
    // Sans indice : l'autorisation a pu être donnée à un autre compte que
    // celui inscrit sur le compte Alanya, et c'est son droit le plus strict.
    return _attempt(silent: true, accountName: null);
  }

  /// Oublie le compte connecté sur cet appareil, pour en choisir un autre.
  ///
  /// Ne révoque rien côté Google : les sauvegardes déjà déposées restent où
  /// elles sont, et l'inscrit peut revenir à ce compte quand il veut. C'est
  /// seulement le choix local qui est effacé, faute de quoi `signIn()`
  /// reconnecterait le compte courant sans rien demander — et « changer de
  /// compte » ne changerait rien du tout.
  static Future<void> forgetAccount() async {
    try {
      await GoogleSignIn(scopes: const [drive.DriveApi.driveFileScope])
          .signOut();
    } catch (_) {
      // Au pire le sélecteur ne s'ouvre pas et l'inscrit reste sur son compte
      // actuel : sans danger, et rien de mieux à tenter ici.
    }
  }

  static Future<DriveBackupTarget?> _attempt({
    required bool silent,
    required String? accountName,
  }) async {
    try {
      final signIn = GoogleSignIn(
        scopes: const [drive.DriveApi.driveFileScope],
        // Réservé à Android par le plugin ; ailleurs il est ignoré.
        forceAccountName: accountName,
      );
      // Silencieux d'abord : réutiliser une autorisation déjà donnée évite de
      // rouvrir un sélecteur de compte à chaque sauvegarde automatique.
      final account =
          await (silent ? signIn.signInSilently() : signIn.signIn());
      if (account == null) {
        debugPrint('[DriveBackup] connexion (silent=$silent) : aucun compte '
            'rendu — annulée par l\'inscrit ou fermée par Google');
        return null;
      }

      final client = await signIn.authenticatedClient();
      if (client == null) {
        debugPrint('[DriveBackup] ${account.email} : connecté mais aucun '
            'jeton d\'accès Drive');
        return null;
      }
      return DriveBackupTarget(drive.DriveApi(client),
          accountEmail: account.email);
    } catch (e) {
      // Rendu `null` plutôt que propagé : l'appelant traite déjà « pas de
      // Drive » comme un cas normal. Mais l'erreur est tracée : sans elle, un
      // blocage côté Google se confond avec un simple « annuler ».
      debugPrint('[DriveBackup] connexion (silent=$silent) échouée : $e');
      return null;
    }
  }

  @override
  String get label => 'Google Drive';

  /// Retrouve le dossier `Alanya`, ou le crée.
  ///
  /// `trashed = false` est indispensable : un dossier mis à la corbeille par
  /// l'inscrit reste listé par l'API, et y écrire ferait disparaître les
  /// sauvegardes suivantes sans qu'aucune erreur ne le signale.
  Future<String> _folder() async {
    final cached = _folderId;
    if (cached != null) return cached;

    final found = await _api.files.list(
      q: "name = '$folderName' and mimeType = '$_folderMime' "
          'and trashed = false',
      $fields: 'files(id)',
      spaces: 'drive',
    );
    final existing = found.files?.firstOrNull?.id;
    if (existing != null) return _folderId = existing;

    final created = await _api.files.create(
      drive.File()
        ..name = folderName
        ..mimeType = _folderMime,
      $fields: 'id',
    );
    return _folderId = created.id!;
  }

  @override
  Future<List<RemoteArchive>> list() async {
    final folder = await _folder();
    final response = await _api.files.list(
      q: "'$folder' in parents and trashed = false",
      $fields: 'files(id,name,size,modifiedTime)',
      orderBy: 'modifiedTime desc',
      spaces: 'drive',
    );
    return (response.files ?? const <drive.File>[])
        .where((f) => f.id != null && f.name != null)
        .map((f) => RemoteArchive(
              id: f.id!,
              name: f.name!,
              bytes: int.tryParse(f.size ?? '') ?? 0,
              modifiedAt: f.modifiedTime ?? DateTime.now().toUtc(),
            ))
        .toList();
  }

  @override
  Future<RemoteArchive> write(File local, String name) async {
    final folder = await _folder();
    final length = await local.length();

    // Un même nom peut déjà exister — le descriptif `latest.json` est réécrit à
    // chaque sauvegarde. On remplace son contenu au lieu d'accumuler des
    // homonymes, que Drive accepte pourtant sans broncher.
    final existing = (await list()).where((a) => a.name == name).firstOrNull;
    final media = drive.Media(local.openRead(), length);

    final drive.File saved;
    if (existing != null) {
      saved = await _api.files.update(
        drive.File(),
        existing.id,
        uploadMedia: media,
        $fields: 'id,name,size,modifiedTime',
      );
    } else {
      saved = await _api.files.create(
        drive.File()
          ..name = name
          ..parents = [folder],
        uploadMedia: media,
        $fields: 'id,name,size,modifiedTime',
      );
    }

    return RemoteArchive(
      id: saved.id!,
      name: name,
      // Drive peut renvoyer la taille avec un temps de retard : on rend celle
      // qu'on vient d'envoyer, que la vérification du service compare ensuite
      // à ce qu'un `list()` annonce réellement.
      bytes: int.tryParse(saved.size ?? '') ?? length,
      modifiedAt: saved.modifiedTime ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<File> read(String id, File into) async {
    final drive.Media media;
    try {
      media = await _api.files.get(
        id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
    } catch (_) {
      // Supprimée depuis, ou accès révoqué : distingué d'une panne réseau pour
      // que l'écran dise « cette sauvegarde n'existe plus » plutôt que
      // d'afficher une erreur technique.
      throw BackupArchiveNotFound(id);
    }

    await into.parent.create(recursive: true);
    final sink = into.openWrite();
    try {
      await media.stream.pipe(sink);
    } finally {
      await sink.close();
    }
    return into;
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _api.files.delete(id);
    } catch (_) {
      // Déjà supprimée : la suppression est idempotente, sans quoi une reprise
      // après coupure échouerait sur le fichier qu'elle venait d'effacer.
    }
  }
}
