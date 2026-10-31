//  Choix du dossier de destination d'un déplacement. Un dossier reste dans sa
//  racine ; un fichier va dans la racine de son type, dans Albums ou dans
//  Partager (décision du 24/10/2026).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../talky_api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_widgets.dart';

/// Destination d'un fichier : d'abord la racine (celle de son type, Albums ou
/// Partager), puis le dossier dans cette racine. [family] nul : plusieurs
/// fichiers de types différents, seuls Albums et Partager les acceptent tous.
/// Rend l'identifiant du dossier choisi, ou null.
Future<int?> pickSafeboxFileDestination(
  BuildContext context, {
  required SafeboxFamily? family,
  required int currentParentId,
}) async {
  final c = context.read<SafeboxController>();
  final vue = c.overview ?? await c.refreshOverview();
  if (vue == null || !context.mounted) return null;
  final l10n = context.l10n;
  final racine = await showAppBottomSheet<SafeboxRoot>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(l10n.safeboxMoveToRoot, style: ctx.text.titleSmall)),
          const Divider(height: 1),
          for (final r in [if (family != null) family.root, SafeboxRoot.albums, SafeboxRoot.partager])
            if (vue.rootIds[r] != null)
              ListTile(
                leading: Icon(safeboxRootIcon(r), color: ctx.colors.primary),
                title: Text(SafeboxController.rootLabel(r, l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, r),
              ),
        ],
      ),
    ),
  );
  if (racine == null || !context.mounted) return null;
  return pickSafeboxDestination(context, startFolderId: vue.rootIds[racine]!, currentParentId: currentParentId);
}

/// Rend l'identifiant du dossier choisi, ou null. `currentParentId` est le
/// dossier actuel (non proposé) ; -1 quand tout dossier convient (choix du
/// rangement d'un fichier envoyé depuis une discussion).
Future<int?> pickSafeboxDestination(
  BuildContext context, {
  required int startFolderId,
  required int currentParentId,
  Set<int> movingFolderIds = const {},
  String? actionLabel,
}) =>
    Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => _ChoixDossier(
          folderId: startFolderId,
          currentParentId: currentParentId,
          movingFolderIds: movingFolderIds,
          actionLabel: actionLabel,
        ),
      ),
    );

class _ChoixDossier extends StatefulWidget {
  const _ChoixDossier({
    required this.folderId,
    required this.currentParentId,
    this.movingFolderIds = const {},
    this.actionLabel,
  });
  final int folderId;
  final int currentParentId;
  /// Les dossiers déplacés : ni eux ni leur contenu ne peuvent les recevoir.
  final Set<int> movingFolderIds;
  final String? actionLabel;

  @override
  State<_ChoixDossier> createState() => _ChoixDossierState();
}

class _ChoixDossierState extends State<_ChoixDossier> {
  SafeboxFolderPage? _page;

  @override
  void initState() {
    super.initState();
    context.read<SafeboxController>().api.fetchSafeboxFolder(widget.folderId).then((p) {
      if (mounted) setState(() => _page = p);
    }).catchError((Object e) {
      if (mounted) safeboxShowError(context, e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = _page;
    final ici = widget.folderId != widget.currentParentId;
    return Scaffold(
      appBar: AppBar(
        title: Text(page == null ? l10n.safeboxMove : SafeboxController.folderLabel(page.folder, l10n)),
      ),
      body: page == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final d in page.folders)
                  if (!widget.movingFolderIds.contains(d.id))
                    ListTile(
                      leading: Icon(Icons.folder_outlined, color: context.colors.primary),
                      title: Text(d.name ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final choisi = await pickSafeboxDestination(
                          context,
                          startFolderId: d.id,
                          currentParentId: widget.currentParentId,
                          movingFolderIds: widget.movingFolderIds,
                          actionLabel: widget.actionLabel,
                        );
                        if (choisi != null && context.mounted) Navigator.pop(context, choisi);
                      },
                    ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppSpacing.card,
          child: FilledButton.icon(
            onPressed: page != null && ici ? () => Navigator.pop(context, widget.folderId) : null,
            icon: const Icon(Icons.drive_file_move_outlined),
            label: Text(widget.actionLabel ?? l10n.safeboxMoveHere),
          ),
        ),
      ),
    );
  }
}
