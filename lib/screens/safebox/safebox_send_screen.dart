//  Envoyer un fichier du coffre dans une discussion (jusqu'à 1 Go). Deux
//  chemins : un fichier déjà dans le coffre part tout de suite, sans copie ;
//  un fichier du téléphone entre d'abord dans Partager (sur l'espace de
//  l'expéditeur), puis part dans la discussion dès la fin de son envoi.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/safebox_share_payload.dart';
import '../../talky_api_client.dart';
import 'safebox_compression_sheet.dart';
import 'safebox_widgets.dart';

/// Ouvre l'écran d'envoi. Rend le contenu du message à envoyer (fichier pris
/// dans le coffre), ou null : renoncement, ou fichier du téléphone dont le
/// message partira de lui-même à la fin de l'envoi.
Future<SafeboxSharePayload?> showSafeboxSend(BuildContext context, {required int conversationId}) =>
    Navigator.push<SafeboxSharePayload>(
      context,
      MaterialPageRoute(builder: (_) => SafeboxSendScreen(conversationId: conversationId)),
    );

/// Envoie des fichiers du téléphone dans une discussion par le coffre : ils
/// entrent dans Partager (décision du 24/10/2026 : pas de question « Ranger
/// dans »), avec la question de compression, sur l'espace de l'expéditeur,
/// puis partent dans la discussion à la fin de leur envoi. Sert à l'écran
/// d'envoi et à la proposition faite quand un fichier dépasse la limite des
/// médias de discussion. Rend vrai si au moins un fichier est en route.
Future<bool> sendPhoneFilesViaSafebox(
  BuildContext context, {
  required int conversationId,
  required List<SafeboxPick> picks,
}) async {
  final c = context.read<SafeboxController>();
  final l10n = context.l10n;
  final vue = c.overview ?? await c.refreshOverview();
  if (vue == null || !context.mounted) return false;
  final racine = vue.rootIds[SafeboxRoot.partager];
  if (racine == null) return false;
  final partager = SafeboxFolder(id: racine, parentId: null, root: SafeboxRoot.partager, name: null, depth: 0);
  final tri = c.triage(picks, partager);
  if (tri.rejected.isNotEmpty) {
    final r = tri.rejected.first;
    safeboxSnack(
      context,
      r.reason == SafeboxRejectReason.tooLarge
          ? l10n.safeboxFileTooLarge(formatBytes(vue.limits.maxFileBytes, l10n))
          : l10n.safeboxEmptyFile,
      error: true,
    );
  }
  if (tri.ok.isEmpty) return false;
  var compresser = false;
  final estimation = await c.estimate(tri.ok);
  if (estimation != null && context.mounted) {
    final retenu = await c.rememberedChoice();
    if (retenu == SafeboxCompressionChoice.ask) {
      if (!context.mounted) return false;
      final r = await showSafeboxCompressionSheet(
        context,
        originalBytes: estimation.original,
        compressedBytes: estimation.compressed,
      );
      if (r == null) return false;
      compresser = r.compress;
      if (r.remember) {
        await c.rememberChoice(r.compress ? SafeboxCompressionChoice.compressed : SafeboxCompressionChoice.original);
      }
    } else {
      compresser = retenu == SafeboxCompressionChoice.compressed;
    }
  }
  final total = tri.ok.fold<int>(0, (s, p) => s + p.size);
  if (!compresser && total > (c.overview ?? vue).quota.freeBytes) {
    if (context.mounted) safeboxSnack(context, l10n.safeboxQuotaExceeded, error: true);
    return false;
  }
  await c.addFiles(tri.ok, partager, compress: compresser, shareConversationId: conversationId);
  if (context.mounted) safeboxSnack(context, l10n.safeboxShareQueued);
  return true;
}

class SafeboxSendScreen extends StatefulWidget {
  const SafeboxSendScreen({super.key, required this.conversationId});
  final int conversationId;

  @override
  State<SafeboxSendScreen> createState() => _SafeboxSendScreenState();
}

class _SafeboxSendScreenState extends State<SafeboxSendScreen> {
  bool _occupe = false;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    if (_c.overview == null) _c.refreshOverview();
  }

  /// Fichier choisi dans le coffre : le partage est créé, le message rendu.
  Future<void> _envoyerDuCoffre(SafeboxFile f) async {
    setState(() => _occupe = true);
    try {
      final payload = await _c.shareFile(f, widget.conversationId);
      if (mounted) Navigator.pop(context, payload);
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  /// Fichier du téléphone : déposé dans Partager, il partira dans la
  /// discussion à la fin de l'envoi.
  Future<void> _depuisLeTelephone() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    final f = res?.files.single;
    if (f == null || f.path == null || !mounted) return;
    final parti = await sendPhoneFilesViaSafebox(
      context,
      conversationId: widget.conversationId,
      picks: [SafeboxPick(path: f.path!, name: f.name, size: f.size)],
    );
    if (parti && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vue = context.watch<SafeboxController>().overview;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxSharePickTitle)),
      body: AbsorbPointer(
        absorbing: _occupe,
        child: ListView(
          children: [
            Padding(
              padding: AppSpacing.card,
              child: Text(
                l10n.safeboxSharePickHint(formatBytes(vue?.limits.maxFileBytes ?? 0, l10n)),
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: AppSpacing.screenH,
              child: OutlinedButton.icon(
                onPressed: _depuisLeTelephone,
                icon: const Icon(Icons.smartphone),
                label: Text(l10n.safeboxSharePickFromPhone),
              ),
            ),
            if (_occupe) const LinearProgressIndicator(),
            AppSpacing.vGapMd,
            if (vue == null)
              const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()))
            else
              for (final r in SafeboxRoot.values)
                if (vue.rootIds[r] != null)
                  ListTile(
                    leading: Icon(safeboxRootIcon(r), color: context.colors.primary),
                    title: Text(SafeboxController.rootLabel(r, l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final f = await Navigator.push<SafeboxFile>(
                        context,
                        MaterialPageRoute(builder: (_) => _Parcourir(folderId: vue.rootIds[r]!)),
                      );
                      if (f != null && mounted) await _envoyerDuCoffre(f);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

/// Un dossier du coffre, pour y choisir un fichier.
class _Parcourir extends StatefulWidget {
  const _Parcourir({required this.folderId});
  final int folderId;

  @override
  State<_Parcourir> createState() => _ParcourirState();
}

class _ParcourirState extends State<_Parcourir> {
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
    return Scaffold(
      appBar: AppBar(title: Text(page == null ? '' : SafeboxController.folderLabel(page.folder, l10n))),
      body: page == null
          ? const Center(child: CircularProgressIndicator())
          : page.folders.isEmpty && page.files.isEmpty
              ? Center(child: Text(l10n.safeboxFolderEmpty))
              : ListView(
                  children: [
                    for (final d in page.folders)
                      ListTile(
                        leading: Icon(Icons.folder_outlined, color: context.colors.primary),
                        title: Text(d.name ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final f = await Navigator.push<SafeboxFile>(
                            context,
                            MaterialPageRoute(builder: (_) => _Parcourir(folderId: d.id)),
                          );
                          if (f != null && context.mounted) Navigator.pop(context, f);
                        },
                      ),
                    for (final f in page.files)
                      ListTile(
                        leading: SafeboxFileThumb(file: f, size: 44),
                        title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatBytes(f.plainBytes, l10n)),
                        trailing: const Icon(Icons.send_outlined),
                        onTap: () => Navigator.pop(context, f),
                      ),
                  ],
                ),
    );
  }
}
