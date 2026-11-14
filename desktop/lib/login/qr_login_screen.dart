// Écran 1 : connexion par QR code, scanné avec Alanya sur le téléphone
// (Réglages › Appareils connectés › Connecter un appareil).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/desktop_api.dart';
import '../core/session_store.dart';
import '../ui/common.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

enum _Etape { chargement, affiche, scanne, refuse, expire, erreur }

class _QrLoginScreenState extends State<QrLoginScreen> {
  /// Codes renouvelés tout seuls avant de demander un clic : la création de
  /// session est limitée côté serveur, et personne ne regarde peut-être l'écran.
  static const _renouvellementsAuto = 3;

  QrSession? _session;
  _Etape _etape = _Etape.chargement;
  Timer? _sondage;
  DateTime? _finCode;
  int _renouveles = 0;
  bool _sondageEnCours = false;
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    _nouveauCode();
  }

  @override
  void dispose() {
    _sondage?.cancel();
    super.dispose();
  }

  Future<void> _nouveauCode() async {
    _sondage?.cancel();
    setState(() => _etape = _Etape.chargement);
    final scope = AppScope.of(context);
    try {
      final s = await scope.session.api.createQrSession(
        deviceId: await scope.session.store.deviceId(),
        deviceName: computerName(),
      );
      if (!mounted) return;
      setState(() {
        _session = s;
        _finCode = DateTime.now().add(s.ttl);
        _etape = _Etape.affiche;
      });
      _sondage = Timer.periodic(const Duration(seconds: 2), (_) => _sonder());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e;
        _etape = _Etape.erreur;
      });
    }
  }

  Future<void> _sonder() async {
    final s = _session;
    if (s == null || _sondageEnCours) return;
    if (_finCode != null && DateTime.now().isAfter(_finCode!)) return _expire();
    _sondageEnCours = true;
    try {
      final r = await AppScope.of(context).session.api.pollQrSession(s);
      if (!mounted || s != _session) return;
      switch (r.status) {
        case QrStatus.pending:
          break;
        case QrStatus.scanned:
          if (_etape != _Etape.scanne) setState(() => _etape = _Etape.scanne);
        case QrStatus.approved:
          if (r.hasTokens) {
            _sondage?.cancel();
            await AppScope.of(context).session.signIn(r);
          }
        case QrStatus.denied:
          _sondage?.cancel();
          setState(() => _etape = _Etape.refuse);
        case QrStatus.expired:
          _expire();
      }
    } catch (_) {
      // Coupure passagère : le prochain sondage réessaie.
    } finally {
      _sondageEnCours = false;
    }
  }

  void _expire() {
    _sondage?.cancel();
    if (_renouveles < _renouvellementsAuto) {
      _renouveles++;
      _nouveauCode();
    } else {
      setState(() => _etape = _Etape.expire);
    }
  }

  void _relancer() {
    _renouveles = 0;
    _nouveauCode();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final ended = AppScope.of(context).session.endedRemotely;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Wrap(
              spacing: 48,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 440,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: Palette.brand, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.lock_outline, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(l.appTitle, style: t.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 28),
                    Text(l.loginTitle, style: t.headlineSmall),
                    const SizedBox(height: 20),
                    if (ended) ...[
                      _Bandeau(icon: Icons.info_outline, text: l.loginEndedRemotely),
                      const SizedBox(height: 16),
                    ],
                    _Pas(n: 1, text: l.loginStep1),
                    _Pas(n: 2, text: l.loginStep2),
                    _Pas(n: 3, text: l.loginStep3),
                    const SizedBox(height: 16),
                    _Bandeau(icon: Icons.shield_outlined, text: l.loginSharedComputer, warning: true),
                  ]),
                ),
                Card(
                  child: SizedBox(
                    width: 340,
                    height: 400,
                    child: Padding(padding: const EdgeInsets.all(24), child: _carte(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _carte(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    Widget message(IconData icon, String titre, String texte, {String? bouton}) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Palette.brand),
            const SizedBox(height: 16),
            Text(titre, style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(texte, style: t.bodySmall, textAlign: TextAlign.center),
            if (bouton != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: _relancer, child: Text(bouton)),
            ],
          ],
        );
    switch (_etape) {
      case _Etape.chargement:
        return const Center(child: CircularProgressIndicator());
      case _Etape.scanne:
        return message(Icons.phone_android_outlined, l.loginScannedTitle, l.loginScannedText);
      case _Etape.refuse:
        return message(Icons.block_outlined, l.loginDeniedTitle, l.loginDeniedText, bouton: l.loginNewCode);
      case _Etape.expire:
        return message(Icons.timer_off_outlined, l.loginExpiredTitle, l.loginExpiredText, bouton: l.loginNewCode);
      case _Etape.erreur:
        return message(Icons.cloud_off_outlined, errorText(context, _erreur), '', bouton: l.retry);
      case _Etape.affiche:
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          QrImageView(
            data: _session!.payload,
            size: 260,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Palette.text),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Palette.text),
            semanticsLabel: l.loginQrLabel,
          ),
          const SizedBox(height: 16),
          Text(l.loginQrHint, style: t.bodySmall, textAlign: TextAlign.center),
        ]);
    }
  }
}

class _Pas extends StatelessWidget {
  const _Pas({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Palette.brandContainer,
            child: Text('$n', style: const TextStyle(color: Palette.brandDark, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          ),
        ]),
      );
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.icon, required this.text, this.warning = false});
  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warning ? Palette.warningContainer : Palette.brandContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: warning ? Palette.warning : Palette.brandDark),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45))),
        ]),
      );
}
