import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/account/warning_banner.dart';
import '../../widgets/common/status_chip.dart';

/// Reconsultation du code de récupération.
///
/// Le code est chiffré côté serveur et non haché, précisément pour pouvoir être
/// réaffiché : un code de secours qu'on ne peut plus relire ramène au problème
/// qu'il devait résoudre. En contrepartie, sa lecture exige le mot de passe —
/// un téléphone déverrouillé et laissé sur une table ne doit pas suffire à
/// repartir avec la clé du compte.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key});

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  String? _code;
  bool _loading = false;
  String? _error;

  Future<void> _reveal() async {
    final l10n = context.l10n;
    final password = await _demanderMotDePasse();
    if (password == null || password.isEmpty || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await context.read<AuthProvider>().revealRecoveryCode(password);
      if (!mounted) return;
      setState(() => _code = code);
    } on TalkyException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      AppLog.e('RecoveryCode', 'Lecture du code échouée', e, st);
      if (mounted) setState(() => _error = l10n.recoveryCodeRevealFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _demanderMotDePasse() {
    final controller = TextEditingController();
    final l10n = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.recoveryCodeReveal),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recoveryCodePasswordPrompt,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            AppSpacing.vGapLg,
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v),
              decoration: InputDecoration(
                hintText: l10n.signupPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.recoveryCodeReveal),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _copier() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.recoveryCodeCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = _code;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.recoveryCodeTitle),
      ),
      body: ListView(
        padding: AppSpacing.screenH.copyWith(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxxl,
        ),
        children: [
          Text(
            l10n.recoveryCodeIntro,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          AppSpacing.vGapXl,
          Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.brMd,
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.recoveryCodeTitle,
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.hGapSm,
                    StatusChip(
                      label: l10n.recoveryCodeKeepSafe,
                      tone: StatusChipTone.warning,
                    ),
                  ],
                ),
                AppSpacing.vGapMd,
                // Le gabarit masqué a la même longueur que le vrai code : rien ne
                // bouge à l'affichage, on ne fait que remplacer les caractères.
                SelectableText(
                  code ?? '••••-••••-••••',
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: code == null
                        ? context.colors.onSurfaceVariant
                        : context.colors.onSurface,
                  ),
                ),
                AppSpacing.vGapLg,
                if (code == null)
                  FilledButton.icon(
                    onPressed: _loading ? null : _reveal,
                    icon: _loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.visibility_outlined),
                    label: Text(l10n.recoveryCodeReveal),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _code = null),
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(l10n.recoveryCodeHide),
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _copier,
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(l10n.copy),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            AppSpacing.vGapLg,
            WarningBanner(
              variant: WarningBannerVariant.error,
              message: _error!,
            ),
          ],
          AppSpacing.vGapXl,
          WarningBanner(
            variant: WarningBannerVariant.info,
            message: l10n.recoveryCodeSecurityWarning,
          ),
        ],
      ),
    );
  }
}
