// Écran 7 : compte, cet ordinateur, fichiers gardés sur l'ordinateur,
// langue, déconnexion.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_version.dart';
import '../core/exporter.dart';
import '../core/session_store.dart';
import '../ui/common.dart';
import '../ui/system.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _deconnecter(BuildContext context) async {
    final l = context.l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.logoutConfirmTitle),
        content: Text(l.logoutConfirmText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await AppScope.of(context).session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final scope = AppScope.of(context);
    final session = scope.session;
    final langue = scope.locale;
    final connecte = session.connectedAt;
    final nom = session.displayName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.navSettings, style: t.headlineSmall),
              const SizedBox(height: 20),
              _Section(l.settingsAccount),
              Card(
                child: Column(children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFC5CAE9),
                      child: Text(
                        nom.isEmpty ? '?' : nom.characters.first.toUpperCase(),
                        style: const TextStyle(color: Palette.brandDark, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                    title: Text(nom.isEmpty ? l.settingsAccount : nom, style: t.titleMedium),
                    subtitle: session.phone.isEmpty ? null : Text(session.phone),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    leading: const Icon(Icons.computer_outlined, color: Palette.brand),
                    title: Text(computerName(), style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      connecte == null
                          ? l.settingsComputerHint
                          : l.settingsConnectedOn(DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).format(connecte)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              _Section(l.settingsFiles),
              const _FichiersOrdinateur(),
              const SizedBox(height: 24),
              _Section(l.settingsApp),
              Card(
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(children: [
                      Expanded(child: Text(l.settingsLanguage, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                      ListenableBuilder(
                        listenable: langue,
                        builder: (context, _) => DropdownButton<String?>(
                          value: langue.locale?.languageCode,
                          underline: const SizedBox.shrink(),
                          onChanged: langue.set,
                          items: [
                            DropdownMenuItem(value: null, child: Text(l.settingsLanguageSystem)),
                            const DropdownMenuItem(value: 'fr', child: Text('Français')),
                            const DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  if (scope.desktop case final d?)
                    ListenableBuilder(
                      listenable: d,
                      builder: (context, _) => Column(children: [
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text(l.settingsKeepRunning, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(d.trayAvailable ? l.settingsKeepRunningHint : l.settingsTrayUnavailable),
                          value: d.trayAvailable && d.keepRunning,
                          onChanged: d.trayAvailable ? d.setKeepRunning : null,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text(l.settingsAutostart, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(l.settingsAutostartHint),
                          value: d.autostart,
                          onChanged: d.setAutostart,
                        ),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3C7C3)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.logoutTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(l.logoutText, style: t.bodySmall?.copyWith(height: 1.5)),
                      ]),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Palette.danger, minimumSize: const Size(0, 44)),
                      onPressed: () => _deconnecter(context),
                      child: Text(l.logout),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(l.settingsVersion(appVersion), style: t.bodySmall),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: Palette.muted),
        ),
      );
}

class _FichiersOrdinateur extends StatefulWidget {
  const _FichiersOrdinateur();

  @override
  State<_FichiersOrdinateur> createState() => _FichiersOrdinateurState();
}

class _FichiersOrdinateurState extends State<_FichiersOrdinateur> {
  Directory? _dossier;
  int? _gardes;
  bool _vidage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dossier == null) _lire();
  }

  Future<void> _lire() async {
    final vault = context.vault;
    final d = await DownloadFolder.get();
    final g = await vault.keptBytes();
    if (mounted) {
      setState(() {
        _dossier = d;
        _gardes = g;
      });
    }
  }

  Future<void> _vider() async {
    setState(() => _vidage = true);
    await context.vault.clearKept();
    await _lire();
    if (mounted) setState(() => _vidage = false);
  }

  Future<void> _changerDossier() async {
    final chemin = await getDirectoryPath(initialDirectory: _dossier?.path, confirmButtonText: context.l.change);
    if (chemin == null) return;
    await DownloadFolder.set(chemin);
    await _lire();
  }

  Future<void> _ouvrirDossier() async {
    final d = _dossier;
    if (d == null) return;
    await d.create(recursive: true);
    await showInFolder(d.path);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    Widget ligne(String titre, String sousTitre, Widget action) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sousTitre, style: t.bodySmall),
              ]),
            ),
            const SizedBox(width: 12),
            action,
          ]),
        );
    return Card(
      child: Column(children: [
        ligne(
          l.settingsDownloadFolder,
          _dossier?.path ?? '…',
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton(onPressed: _dossier == null ? null : _ouvrirDossier, child: Text(l.open)),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _changerDossier, child: Text(l.change)),
          ]),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        ligne(
          l.settingsKeptFiles,
          _gardes == null ? '…' : l.settingsKeptFilesSize(formatBytes(context, _gardes!)),
          OutlinedButton(
            onPressed: _vidage || (_gardes ?? 0) == 0 ? null : _vider,
            child: Text(l.empty),
          ),
        ),
      ]),
    );
  }
}
