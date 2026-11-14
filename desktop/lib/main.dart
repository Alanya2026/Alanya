// Alanya Coffre-fort : le coffre-fort Alanya sur Windows et Linux.
// Conception : backend/docs/conception/coffre-bureau.html.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';

import 'core/app_version.dart';
import 'core/desktop_api.dart';
import 'core/desktop_integration.dart';
import 'core/session.dart';
import 'core/session_store.dart';
import 'core/settings.dart';
import 'core/vault.dart';
import 'l10n/app_localizations.dart';
import 'login/qr_login_screen.dart';
import 'shell/shell.dart';
import 'ui/common.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lecteur vidéo et audio (libmpv) de la visionneuse.
  MediaKit.ensureInitialized();
  final store = SessionStore();
  final session = Session(api: DesktopApi(store: store), store: store);
  final locale = LocaleSetting();
  await Future.wait([session.start(), locale.load()]);
  appVersion = await loadAppVersion();
  final updates = UpdateChecker(current: appVersion)..start();
  final desktop = DesktopIntegration()..signedIn = (() => session.phase == SessionPhase.signedIn);
  await desktop.start(hidden: args.contains('--hidden'));
  runApp(CoffreApp(session: session, locale: locale, updates: updates, desktop: desktop));
}

class CoffreApp extends StatefulWidget {
  const CoffreApp({super.key, required this.session, required this.locale, this.updates, this.desktop});
  final Session session;
  final LocaleSetting locale;
  final UpdateChecker? updates;
  final DesktopIntegration? desktop;

  @override
  State<CoffreApp> createState() => _CoffreAppState();
}

class _CoffreAppState extends State<CoffreApp> {
  /// Un coffre par connexion : rien du compte précédent (aperçus déchiffrés
  /// en mémoire) ne survit à une déconnexion.
  Vault? _vault;
  final _navigateur = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_session);
    widget.session.beforeWipe = () async => _vault?.close();
    _session();
  }

  @override
  void dispose() {
    widget.session.removeListener(_session);
    widget.session.beforeWipe = null;
    _vault?.dispose();
    super.dispose();
  }

  void _session() {
    final connecte = widget.session.phase == SessionPhase.signedIn;
    if (connecte && _vault == null) {
      setState(() => _vault = Vault(widget.session.api));
    } else if (!connecte && _vault != null) {
      // Visionneuse ou boîte de dialogue ouverte : on revient à la racine
      // avant de retirer le coffre.
      _navigateur.currentState?.popUntil((r) => r.isFirst);
      final ancien = _vault;
      setState(() => _vault = null);
      WidgetsBinding.instance.addPostFrameCallback((_) => ancien?.dispose());
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.locale,
        builder: (context, _) => AppScope(
          session: widget.session,
          locale: widget.locale,
          vault: _vault,
          updates: widget.updates,
          desktop: widget.desktop,
          child: MaterialApp(
            // Le menu de l'icône près de l'horloge suit la langue.
            builder: (context, child) {
              final d = widget.desktop;
              if (d != null) {
                final backup = _vault?.pcBackup;
                d.onBackupNow = backup?.runNow;
                unawaited(d.setMenu(AppLocalizations.of(context), backup: backup != null));
              }
              return child ?? const SizedBox.shrink();
            },
            navigatorKey: _navigateur,
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: widget.locale.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: switch (widget.session.phase) {
              SessionPhase.starting => const Scaffold(body: Center(child: CircularProgressIndicator())),
              SessionPhase.signedOut => const QrLoginScreen(),
              SessionPhase.signedIn => const Shell(),
            },
          ),
        ),
      );
}
