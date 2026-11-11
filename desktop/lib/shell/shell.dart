// La fenêtre une fois connecté : barre latérale à gauche, contenu à droite.

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';

import '../browse/folder_view.dart';
import '../browse/home_view.dart';
import '../settings/settings_view.dart';
import '../ui/common.dart';
import 'export_bar.dart';
import 'transfer_bar.dart';

/// Ce que montre la partie droite.
sealed class Destination {
  const Destination();
}

class HomeDestination extends Destination {
  const HomeDestination();
}

/// Un dossier du coffre ; [root] dit quelle entrée de la barre est active.
class FolderDestination extends Destination {
  const FolderDestination(this.root, this.folderId);
  final SafeboxRoot root;
  final int folderId;
}

class SettingsDestination extends Destination {
  const SettingsDestination();
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Destination _ici = const HomeDestination();
  final List<Destination> _precedents = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = context.vault;
    if (v.overview == null && !v.loading) v.refresh();
  }

  void _aller(Destination d, {bool garderRetour = true}) {
    if (garderRetour) _precedents.add(_ici);
    setState(() => _ici = d);
  }

  void _racine(SafeboxRoot r) {
    final id = context.vault.rootId(r);
    if (id == null) return;
    _precedents.clear();
    _aller(FolderDestination(r, id), garderRetour: false);
  }

  void _retour() {
    if (_precedents.isEmpty) return;
    setState(() => _ici = _precedents.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.vault;
    return Scaffold(
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListenableBuilder(
          listenable: vault,
          builder: (context, _) => _Barre(
            ici: _ici,
            onHome: () {
              _precedents.clear();
              _aller(const HomeDestination(), garderRetour: false);
            },
            onRoot: _racine,
            onSettings: () {
              _precedents.clear();
              _aller(const SettingsDestination(), garderRetour: false);
            },
          ),
        ),
        Expanded(
          child: Column(children: [
            Expanded(
              child: switch (_ici) {
            HomeDestination() => HomeView(
                onOpenRoot: _racine,
                onOpenFolder: (root, id) => _aller(FolderDestination(root, id)),
              ),
            FolderDestination(:final root, :final folderId) => FolderView(
                key: ValueKey(folderId),
                root: root,
                folderId: folderId,
                onOpenFolder: (id) => _aller(FolderDestination(root, id)),
                onBack: _precedents.isEmpty ? null : _retour,
              ),
            SettingsDestination() => const SettingsView(),
              },
            ),
            const TransferBar(),
            const ExportBar(),
          ]),
        ),
      ]),
    );
  }
}

class _Barre extends StatelessWidget {
  const _Barre({required this.ici, required this.onHome, required this.onRoot, required this.onSettings});

  final Destination ici;
  final VoidCallback onHome;
  final void Function(SafeboxRoot) onRoot;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final vault = context.vault;
    final quota = vault.overview?.quota;
    final ici = this.ici;
    return Container(
      width: 240,
      decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Palette.border))),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 18),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Palette.brand, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.safeboxName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Text('Alanya', style: TextStyle(fontSize: 12, color: Palette.muted)),
            ]),
          ]),
        ),
        Expanded(
          child: ListView(children: [
            _Entree(icon: Icons.home_outlined, label: l.navHome, active: ici is HomeDestination, onTap: onHome),
            for (final r in SafeboxRoot.values)
              _Entree(
                icon: rootIcon(r),
                label: rootName(context, r),
                active: ici is FolderDestination && ici.root == r,
                onTap: vault.rootId(r) == null ? null : () => onRoot(r),
              ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Divider(height: 1)),
            _Entree(
              icon: Icons.settings_outlined,
              label: l.navSettings,
              active: ici is SettingsDestination,
              onTap: onSettings,
            ),
          ]),
        ),
        if (quota != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                l.spaceUsedOf(formatBytes(context, quota.usedBytes), formatBytes(context, quota.quotaBytes)),
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: quota.ratio,
                  minHeight: 6,
                  backgroundColor: Palette.border,
                  color: quota.ratio > 0.9 ? Palette.danger : Palette.brand,
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Entree extends StatelessWidget {
  const _Entree({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: active ? Palette.brandContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(icon, size: 20, color: active ? Palette.brandDark : Palette.text),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: active ? Palette.brandDark : Palette.text,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
