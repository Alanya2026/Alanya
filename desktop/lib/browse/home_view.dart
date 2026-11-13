// Écran 2 : l'accueil. Espace utilisé, les six dossiers, les albums récents.

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';

import '../ui/common.dart';
import 'thumbnail.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.onOpenRoot, required this.onOpenFolder, required this.onFreeUp});

  final void Function(SafeboxRoot) onOpenRoot;
  final void Function(SafeboxRoot root, int folderId) onOpenFolder;
  final VoidCallback onFreeUp;

  @override
  Widget build(BuildContext context) {
    final vault = context.vault;
    final l = context.l;
    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        final o = vault.overview;
        if (o == null) {
          return vault.error != null
              ? ErrorPanel(error: vault.error, onRetry: vault.refresh)
              : const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: vault.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            children: [
              Row(children: [
                Expanded(child: Text(l.navHome, style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                  tooltip: l.refresh,
                  onPressed: vault.loading ? null : vault.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ]),
              const SizedBox(height: 20),
              _Espace(quota: o.quota, onFreeUp: onFreeUp),
              const SizedBox(height: 28),
              _Titre(l.homeFolders),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, c) {
                final colonnes = c.maxWidth > 900 ? 3 : 2;
                const ecart = 12.0;
                final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
                return Wrap(spacing: ecart, runSpacing: ecart, children: [
                  for (final r in SafeboxRoot.values)
                    SizedBox(
                      width: largeur,
                      child: _Dossier(root: r, usage: o.quota.byRoot[r], onTap: () => onOpenRoot(r)),
                    ),
                ]);
              }),
              if (vault.recentAlbums.isNotEmpty) ...[
                const SizedBox(height: 28),
                _Titre(l.homeRecentAlbums),
                const SizedBox(height: 12),
                Wrap(spacing: 16, runSpacing: 16, children: [
                  for (final a in vault.recentAlbums)
                    _Album(album: a, onTap: () => onOpenFolder(SafeboxRoot.albums, a.folder.id)),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500));
}

class _Espace extends StatelessWidget {
  const _Espace({required this.quota, required this.onFreeUp});
  final SafeboxQuota quota;
  final VoidCallback onFreeUp;

  static const _couleurs = {
    SafeboxRoot.photos: Color(0xFF3F51B5),
    SafeboxRoot.videos: Color(0xFF7986CB),
    SafeboxRoot.audios: Color(0xFF26A69A),
    SafeboxRoot.documents: Color(0xFFFFA726),
    SafeboxRoot.albums: Color(0xFFAB47BC),
    SafeboxRoot.partager: Color(0xFF78909C),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final total = quota.quotaBytes <= 0 ? 1 : quota.quotaBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Text(
                l.spaceUsedOf(formatBytes(context, quota.usedBytes), formatBytes(context, quota.quotaBytes)),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            Text(l.spaceFree(formatBytes(context, quota.freeBytes)), style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                for (final r in SafeboxRoot.values)
                  if ((quota.byRoot[r]?.bytes ?? 0) > 0)
                    Expanded(
                      flex: ((quota.byRoot[r]!.bytes / total) * 1000).ceil(),
                      child: ColoredBox(color: _couleurs[r]!),
                    ),
                Expanded(
                  flex: (((total - quota.usedBytes).clamp(0, total) / total) * 1000).ceil(),
                  child: const ColoredBox(color: Palette.border),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 18, runSpacing: 6, children: [
            for (final r in SafeboxRoot.values)
              if ((quota.byRoot[r]?.bytes ?? 0) > 0)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _couleurs[r], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    '${rootName(context, r)} · ${formatBytes(context, quota.byRoot[r]!.bytes)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
            if (quota.trashBytes > 0)
              Text(l.spaceTrash(formatBytes(context, quota.trashBytes)), style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onFreeUp,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: Text(l.freeUp),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Dossier extends StatelessWidget {
  const _Dossier({required this.root, required this.usage, required this.onTap});
  final SafeboxRoot root;
  final SafeboxRootUsage? usage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final u = usage;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Palette.brandContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(rootIcon(root), color: Palette.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rootName(context, root), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  u == null || u.files == 0
                      ? l.folderEmpty
                      : '${l.fileCount(u.files)} · ${formatBytes(context, u.bytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Palette.muted),
          ]),
        ),
      ),
    );
  }
}

class _Album extends StatelessWidget {
  const _Album({required this.album, required this.onTap});
  final SafeboxRecentAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couvertures = album.cover.take(4).toList();
    return SizedBox(
      width: 200,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: couvertures.isEmpty
                  ? const ColoredBox(
                      color: Palette.brandContainer,
                      child: Center(child: Icon(Icons.grid_view_outlined, color: Palette.brand, size: 40)),
                    )
                  : GridView.count(
                      crossAxisCount: couvertures.length == 1 ? 1 : 2,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [for (final f in couvertures) Thumbnail(file: f, radius: 0)],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(folderName(context, album.folder), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          Text(context.l.fileCount(album.fileCount), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
