// Ranger (lot D5) : renommer, créer, déplacer, ajouter à un album, mettre à
// la corbeille. Mêmes routes et mêmes règles que le téléphone :
//  - un fichier va dans la racine de son type, dans Albums ou dans Partager ;
//    un dossier reste dans sa racine ;
//  - un album reçoit des fichiers sans copie (l'espace ne change pas) ;
//  - un fichier rangé à plusieurs endroits : « ici seulement » ou « partout »,
//    seul « partout » libère sa place (quand la corbeille est vidée).

import 'dart:async';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';

import '../ui/common.dart';

// ── Petites fenêtres ───────────────────────────────────────────────────────

void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, width: 480));

void showErrorSnack(BuildContext context, Object e) => showSnack(context, errorText(context, e));

/// Demande un nom. Pour un fichier ([keepExtension]), seul le nom sans
/// l'extension est sélectionné au départ.
Future<String?> askName(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String initial = '',
  int maxLength = 80,
  bool keepExtension = false,
}) {
  final champ = TextEditingController(text: initial);
  final point = initial.lastIndexOf('.');
  champ.selection = TextSelection(
    baseOffset: 0,
    extentOffset: keepExtension && point > 0 ? point : initial.length,
  );
  return showDialog<String>(
    context: context,
    builder: (context) {
      void valider() {
        final nom = champ.text.trim();
        if (nom.isNotEmpty) Navigator.pop(context, nom);
      }

      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: champ,
            autofocus: true,
            maxLength: maxLength > 0 ? maxLength : null,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (_) => valider(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l.cancel)),
          ListenableBuilder(
            listenable: champ,
            builder: (context, _) => FilledButton(
              onPressed: champ.text.trim().isEmpty ? null : valider,
              child: Text(action),
            ),
          ),
        ],
      );
    },
  ).whenComplete(champ.dispose);
}

/// Confirmation d'une action qui ne se rattrape pas.
Future<bool> confirmDanger(BuildContext context, {required String message, required String action}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: SizedBox(width: 420, child: Text(message, style: const TextStyle(height: 1.4))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Palette.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Un fichier aussi rangé ailleurs : vrai = partout, faux = ici seulement.
Future<bool?> askHereOrEverywhere(BuildContext context, {required int count, required String here, required String elsewhere}) {
  final l = context.l;
  Widget choix(BuildContext context, {required bool partout, required IconData icone, required String titre, required String detail}) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icone, color: partout ? Palette.danger : Palette.brand),
        title: Text(titre, style: TextStyle(color: partout ? Palette.danger : null, fontWeight: FontWeight.w500)),
        subtitle: Text(detail),
        onTap: () => Navigator.pop(context, partout),
      );
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.deleteWhich(count)),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          choix(context,
              partout: false,
              icone: Icons.remove_circle_outline,
              titre: l.deleteHereOnly(here),
              detail: l.deleteHereOnlyHint(elsewhere)),
          const SizedBox(height: 6),
          choix(context,
              partout: true, icone: Icons.delete_outline, titre: l.deleteEverywhere, detail: l.deleteEverywhereHint),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))],
    ),
  );
}

/// Choisit un dossier d'arrivée parmi [roots] et leurs sous-dossiers. Rend
/// son identifiant, ou null. Le dossier actuel ([currentParentId]) et les
/// dossiers déplacés ([moving]) ne sont pas proposés.
Future<int?> pickDestination(
  BuildContext context, {
  required List<SafeboxRoot> roots,
  required int currentParentId,
  Set<int> moving = const {},
  String? title,
  String? action,
}) =>
    showDialog<int>(
      context: context,
      // AppScope est au-dessus de MaterialApp : la fenêtre y a accès.
      builder: (_) => _ChoixDossier(
        roots: roots,
        currentParentId: currentParentId,
        moving: moving,
        title: title ?? context.l.moveTitle,
        action: action ?? context.l.moveHere,
      ),
    );

class _ChoixDossier extends StatefulWidget {
  const _ChoixDossier({
    required this.roots,
    required this.currentParentId,
    required this.moving,
    required this.title,
    required this.action,
  });
  final List<SafeboxRoot> roots;
  final int currentParentId;
  final Set<int> moving;
  final String title;
  final String action;

  @override
  State<_ChoixDossier> createState() => _ChoixDossierState();
}

class _ChoixDossierState extends State<_ChoixDossier> {
  /// Le chemin parcouru ; vide = la liste des racines.
  final List<SafeboxFolder> _chemin = [];
  SafeboxFolderPage? _page;
  Object? _erreur;
  int? _essai;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chemin.isEmpty && _page == null && widget.roots.length == 1) {
      final id = context.vault.rootId(widget.roots.single);
      if (id != null) _ouvrir(id);
    }
  }

  Future<void> _ouvrir(int id) async {
    _essai = id;
    setState(() {
      _page = null;
      _erreur = null;
    });
    try {
      final p = await context.vault.folder(id);
      if (!mounted) return;
      setState(() {
        _page = p;
        _chemin.add(p.folder);
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  Future<void> _remonter() async {
    if (_chemin.length <= 1) {
      setState(() {
        _chemin.clear();
        _page = null;
      });
      return;
    }
    _chemin.removeLast();
    final parent = _chemin.removeLast();
    await _ouvrir(parent.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final vault = context.vault;
    final page = _page;
    final ici = _chemin.isEmpty ? null : _chemin.last;
    final racines = _chemin.isEmpty && widget.roots.length > 1;
    final peutRevenir = _chemin.length > 1 || (_chemin.isNotEmpty && widget.roots.length > 1);
    return AlertDialog(
      title: Row(children: [
        if (peutRevenir) IconButton(tooltip: l.back, onPressed: _remonter, icon: const Icon(Icons.arrow_back)),
        Expanded(child: Text(ici == null ? widget.title : folderName(context, ici), overflow: TextOverflow.ellipsis)),
      ]),
      content: SizedBox(
        width: 480,
        height: 360,
        child: racines
            ? ListView(children: [
                for (final r in widget.roots)
                  if (vault.rootId(r) != null)
                    ListTile(
                      leading: Icon(rootIcon(r), color: Palette.brand),
                      title: Text(rootName(context, r)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _ouvrir(vault.rootId(r)!),
                    ),
              ])
            : _erreur != null
                ? ErrorPanel(error: _erreur, onRetry: () => _ouvrir(_essai!))
                : page == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(children: [
                        for (final d in page.folders)
                          if (!widget.moving.contains(d.id))
                            ListTile(
                              leading: const Icon(Icons.folder_outlined, color: Palette.brand),
                              title: Text(folderName(context, d)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _ouvrir(d.id),
                            ),
                      ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: ici != null && page != null && ici.id != widget.currentParentId ? () => Navigator.pop(context, ici.id) : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

// ── Les actions ────────────────────────────────────────────────────────────

/// Où un fichier peut aller : la racine de son type (si tous ont le même),
/// Albums et Partager. Un dossier reste dans sa racine.
List<SafeboxRoot> destinationRoots({required SafeboxRoot current, required List<SafeboxFile> files, required bool withFolders}) {
  if (withFolders) return [current];
  final familles = files.map((f) => f.family).toSet();
  return [if (familles.length == 1) familles.first.root, SafeboxRoot.albums, SafeboxRoot.partager];
}

String placeName(BuildContext context, SafeboxPlace p) => p.folderName ?? rootName(context, p.root);

/// Renomme un fichier ; vrai s'il a changé.
Future<bool> renameFile(BuildContext context, SafeboxFile f) async {
  final l = context.l;
  final vault = context.vault;
  final nom = await askName(
    context,
    title: l.rename,
    label: l.fileNameLabel,
    action: l.rename,
    initial: f.name,
    maxLength: vault.overview?.limits.fileNameMax ?? 180,
    keepExtension: true,
  );
  if (nom == null || nom == f.name || !context.mounted) return false;
  try {
    await vault.api.updateSafeboxFile(f.id, name: nom);
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
    return false;
  }
}

Future<bool> renameFolder(BuildContext context, SafeboxFolder d) async {
  final l = context.l;
  final vault = context.vault;
  final nom = await askName(
    context,
    title: l.rename,
    label: d.root == SafeboxRoot.albums ? l.albumNameLabel : l.folderNameLabel,
    action: l.rename,
    initial: d.name ?? '',
    maxLength: vault.overview?.limits.folderNameMax ?? 80,
  );
  if (nom == null || nom == d.name || !context.mounted) return false;
  try {
    await vault.api.updateSafeboxFolder(d.id, name: nom);
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
    return false;
  }
}

/// « Nouveau dossier » (« Nouvel album » à la racine d'Albums).
Future<bool> createFolder(BuildContext context, SafeboxFolder parent) async {
  final l = context.l;
  final vault = context.vault;
  final album = parent.root == SafeboxRoot.albums && parent.parentId == null;
  final nom = await askName(
    context,
    title: album ? l.newAlbum : l.newFolder,
    label: album ? l.albumNameLabel : l.folderNameLabel,
    action: l.create,
    maxLength: vault.overview?.limits.folderNameMax ?? 80,
  );
  if (nom == null || !context.mounted) return false;
  try {
    await vault.api.createSafeboxFolder(parentId: parent.id, name: nom);
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
    return false;
  }
}

/// Déplace des fichiers et des dossiers ; vrai si quelque chose a bougé.
Future<bool> moveItems(
  BuildContext context, {
  required SafeboxRoot root,
  required int currentFolderId,
  required List<SafeboxFile> files,
  required List<SafeboxFolder> folders,
}) async {
  final l = context.l;
  final vault = context.vault;
  final cible = await pickDestination(
    context,
    roots: destinationRoots(current: root, files: files, withFolders: folders.isNotEmpty),
    currentParentId: currentFolderId,
    moving: {for (final d in folders) d.id},
  );
  if (cible == null || !context.mounted) return false;
  var n = 0;
  try {
    for (final d in folders) {
      await vault.api.updateSafeboxFolder(d.id, parentId: cible);
      n += 1;
    }
    for (final f in files) {
      await vault.api.updateSafeboxFile(f.id, folderId: cible);
      n += 1;
    }
    if (context.mounted) showSnack(context, l.moved(n));
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
  vault.folderChanged(cible);
  return n > 0;
}

/// Ajoute des fichiers à un album, sans copie.
Future<void> addToAlbum(BuildContext context, List<SafeboxFile> files, {required int currentFolderId}) async {
  final l = context.l;
  final vault = context.vault;
  if (files.isEmpty) return;
  final cible = await pickDestination(
    context,
    roots: const [SafeboxRoot.albums],
    currentParentId: currentFolderId,
    title: l.addToAlbumTitle,
    action: l.addHere,
  );
  if (cible == null || !context.mounted) return;
  try {
    for (var i = 0; i < files.length; i += 50) {
      final morceau = files.sublist(i, (i + 50).clamp(0, files.length));
      await vault.api.addSafeboxFilesToFolder(cible, [for (final f in morceau) f.id]);
    }
    if (context.mounted) showSnack(context, l.addedToAlbum(files.length));
    vault.folderChanged(cible);
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}

/// Met à la corbeille ; vrai si quelque chose est parti. [here] : le nom du
/// dossier où l'on est, pour « Retirer de … seulement ».
Future<bool> trashItems(
  BuildContext context, {
  required List<SafeboxFile> files,
  required List<SafeboxFolder> folders,
  required String here,
}) async {
  final l = context.l;
  final vault = context.vault;
  if (files.isEmpty && folders.isEmpty) return false;
  var partout = false;
  final ailleurs = files.where((f) => f.alsoIn.isNotEmpty).toList();
  if (ailleurs.isNotEmpty) {
    final autres = {for (final f in ailleurs) for (final p in f.alsoIn) placeName(context, p)}.join(', ');
    final choix = await askHereOrEverywhere(context, count: ailleurs.length, here: here, elsewhere: autres);
    if (choix == null || !context.mounted) return false;
    partout = choix;
  }
  var n = 0;
  try {
    for (final d in folders) {
      await vault.api.trashSafeboxFolder(d.id);
      n += 1;
    }
    for (final f in files) {
      await vault.api.trashSafeboxFile(f.id, everywhere: partout);
      await vault.downloads.evict(f.id);
      if (partout) {
        for (final p in f.alsoIn) {
          await vault.downloads.evict(p.fileId);
        }
      }
      n += 1;
    }
    if (context.mounted) showSnack(context, l.movedToTrash(n));
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
  unawaited(vault.refresh());
  return n > 0;
}
