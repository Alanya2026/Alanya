import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';

/// Suppression de compte : avertissement → confirmation → grâce 7 jours.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  int _step = 0;
  bool _submitting = false;
  bool _cancelling = false;
  AccountDeletionSchedule? _schedule;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final password = _passwordController.text;
    if (password.isEmpty) return;
    if (_confirmController.text.trim() != l10n.deleteAccountConfirmWord) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountConfirmMismatch)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final schedule =
          await context.read<TalkyApiClient>().deleteAccount(password);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _schedule = schedule;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailed('$e'))),
      );
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _cancelling = true);
    final l10n = context.l10n;
    try {
      await context.read<TalkyApiClient>().cancelAccountDeletion();
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountCancelSuccess)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountCancelFailed)),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  String _formatDate(DateTime dt) {
    final locale = LocaleController.instance.resolvedLocale.toString();
    return DateFormat.yMMMMd(locale).add_Hm().format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(l10n.deleteAccountTitle),
        automaticallyImplyLeading: _step < 2,
      ),
      body: Column(
        children: [
          _StepDots(current: _step),
          Expanded(
            child: switch (_step) {
              0 => _buildWarningStep(context),
              1 => _buildConfirmStep(context),
              _ => _buildGraceStep(context),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWarningStep(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.brMd,
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteAccountStep1Title,
                  style: context.text.titleMedium?.copyWith(
                    color: context.colors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.vGapMd,
                ...[
                  l10n.deleteAccountStep1Bullet1,
                  l10n.deleteAccountStep1Bullet2,
                  l10n.deleteAccountStep1Bullet3,
                ].map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: context.text.bodyMedium),
                        Expanded(child: Text(b, style: context.text.bodyMedium)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            onPressed: () => setState(() => _step = 1),
            child: Text(l10n.deleteAccountContinue),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.deleteAccountPassword,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          AppSpacing.vGapXxl,
          TextField(
            controller: _confirmController,
            decoration: InputDecoration(
              labelText: l10n.deleteAccountConfirmLabel,
              hintText: l10n.deleteAccountConfirmWord,
              prefixIcon: const Icon(Icons.warning_amber_outlined),
            ),
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onPrimary,
                    ),
                  )
                : Text(l10n.deleteAccountSubmit),
          ),
        ],
      ),
    );
  }

  Widget _buildGraceStep(BuildContext context) {
    final l10n = context.l10n;
    final schedule = _schedule;
    final dateLabel = schedule != null
        ? _formatDate(schedule.scheduledAt)
        : '—';
    final days = schedule?.graceDays ?? 7;

    return Padding(
      padding: AppSpacing.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top, size: 56, color: context.colors.primary),
          AppSpacing.vGapLg,
          Text(
            l10n.deleteAccountGraceTitle,
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.vGapSm,
          Text(
            l10n.deleteAccountGraceDays(days),
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.primary,
            ),
          ),
          AppSpacing.vGapMd,
          Text(
            l10n.deleteAccountGraceBody(dateLabel),
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapXxl,
          FilledButton(
            onPressed: _cancelling ? null : _cancelDeletion,
            child: _cancelling
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onPrimary,
                    ),
                  )
                : Text(l10n.deleteAccountCancelDeletion),
          ),
          AppSpacing.vGapSm,
          TextButton(
            onPressed: _logout,
            child: Text(l10n.deleteAccountLogoutNow),
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? context.colors.primary
                  : context.colors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
