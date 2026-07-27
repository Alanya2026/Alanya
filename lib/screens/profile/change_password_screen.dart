import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final current = _currentController.text;
    final next = _newController.text;
    if (current == next) {
      setState(() => _error = context.l10n.changePasswordSameAsCurrent);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().changePassword(
            currentPassword: current,
            newPassword: next,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.changePasswordSuccess)),
      );
      Navigator.pop(context, true);
    } on TalkyException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.errorColon('$e');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.changePasswordTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxl,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.changePasswordSubtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.vGapXxl,
                TextFormField(
                  controller: _currentController,
                  obscureText: _obscureCurrent,
                  validator: (v) => Validators.required(v, l10n: l10n),
                  decoration: InputDecoration(
                    labelText: l10n.changePasswordCurrent,
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: context.colors.surface,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                AppSpacing.vGapLg,
                TextFormField(
                  controller: _newController,
                  obscureText: _obscureNew,
                  validator: (v) => Validators.minLength(v, 6, l10n: l10n),
                  decoration: InputDecoration(
                    labelText: l10n.changePasswordNew,
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: context.colors.surface,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                AppSpacing.vGapLg,
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  validator: (v) => Validators.passwordMatch(
                    v,
                    _newController.text,
                    l10n: l10n,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.changePasswordConfirm,
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: context.colors.surface,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  AppSpacing.vGapLg,
                  Container(
                    padding: AppSpacing.card,
                    decoration: BoxDecoration(
                      color: context.colors.errorContainer,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.colors.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                AppSpacing.vGapXxl,
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd,
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onPrimary,
                          ),
                        )
                      : Text(
                          l10n.changePasswordSubmit,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
