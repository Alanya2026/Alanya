// Alanya Coffre-fort : le coffre-fort Alanya sur Windows et Linux.
// Conception : backend/docs/conception/coffre-bureau.html.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/desktop_api.dart';
import 'core/session.dart';
import 'core/session_store.dart';
import 'core/settings.dart';
import 'core/vault.dart';
import 'l10n/app_localizations.dart';
import 'login/qr_login_screen.dart';
import 'shell/shell.dart';
import 'ui/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SessionStore();
  final session = Session(api: DesktopApi(store: store), store: store);
  final locale = LocaleSetting();
  await Future.wait([session.start(), locale.load()]);
  runApp(CoffreApp(session: session, locale: locale));
}

class CoffreApp extends StatefulWidget {
  const CoffreApp({super.key, required this.session, required this.locale});
  final Session session;
  final LocaleSetting locale;

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
    _session();
  }

  @override
  void dispose() {
    widget.session.removeListener(_session);
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
          child: MaterialApp(
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
