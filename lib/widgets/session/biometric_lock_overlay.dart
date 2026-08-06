import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/biometric_lock_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Masque l'app tant que la biométrie n'a pas validé l'accès (cold start / resume).
class BiometricLockOverlay extends StatefulWidget {
  const BiometricLockOverlay({
    super.key,
    required this.child,
    required this.sessionActive,
  });

  final Widget child;
  final bool sessionActive;

  @override
  State<BiometricLockOverlay> createState() => _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends State<BiometricLockOverlay>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _promptScheduled = false;
  /// Faux après un déverrouillage réussi ; repasse à vrai quand l'app passe en arrière-plan.
  bool _requireUnlock = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeLock());
    });
  }

  @override
  void didUpdateWidget(covariant BiometricLockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionActive && !oldWidget.sessionActive) {
      _requireUnlock = true;
      unawaited(_maybeLock());
    }
    if (!widget.sessionActive) {
      setState(() {
        _locked = false;
        _requireUnlock = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _requireUnlock = true;
        break;
      case AppLifecycleState.resumed:
        unawaited(_maybeLock());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _maybeLock() async {
    if (!widget.sessionActive || _promptScheduled || !_requireUnlock) return;

    final biometric = context.read<BiometricLockService>();
    await biometric.ensureLoaded();
    if (!mounted) return;

    if (!biometric.isEnabled) {
      if (_locked) setState(() => _locked = false);
      return;
    }

    _promptScheduled = true;
    setState(() => _locked = true);

    final ok = await biometric.authenticate(
      reason: context.l10n.biometricLockSubtitle,
    );

    _promptScheduled = false;
    if (!mounted) return;

    if (ok) {
      _requireUnlock = false;
      setState(() => _locked = false);
    } else {
      setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLock = _locked && widget.sessionActive;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: showLock,
          child: widget.child,
        ),
        if (showLock)
          ColoredBox(
            color: context.colors.surface.withValues(alpha: 0.98),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: context.colors.primary,
                      ),
                      AppSpacing.vGapLg,
                      Text(
                        context.l10n.biometricLockTitle,
                        style: context.text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.vGapSm,
                      Text(
                        context.l10n.biometricLockSubtitle,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.vGapXxl,
                      FilledButton(
                        onPressed: _maybeLock,
                        child: Text(context.l10n.biometricLockUnlock),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
