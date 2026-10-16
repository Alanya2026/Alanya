//  Choix du dossier de destination d'un déplacement. On ne navigue que dans la
//  famille de l'élément : un fichier ou un dossier reste dans sa famille.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../talky_api_client.dart';
import '../../core/theme/app_theme.dart';
import 'safebox_widgets.dart';

/// Rend l'identifiant du dossier choisi, ou null.
Future<int?> pickSafeboxDestination(
  BuildContext context, {
  required int startFolderId,
  required int currentParentId,
  int? movingFolderId,
}) =>
    Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => _ChoixDossier(
          folderId: startFolderId,
          currentParentId: currentParentId,
          movingFolderId: movingFolderId,
        ),
      ),
    );

class _ChoixDossier extends StatefulWidget {
  const _ChoixDossier({required this.folderId, required this.currentParentId, this.movingFolderId});
  final int folderId;
  final int currentParentId;
  final int? movingFolderId;

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
                  if (d.id != widget.movingFolderId)
                    ListTile(
                      leading: Icon(Icons.folder_outlined, color: context.colors.primary),
                      title: Text(d.name ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final choisi = await pickSafeboxDestination(
                          context,
                          startFolderId: d.id,
                          currentParentId: widget.currentParentId,
                          movingFolderId: widget.movingFolderId,
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
            label: Text(l10n.safeboxMoveHere),
          ),
        ),
      ),
    );
  }
}
