import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/translation/message_translation_service.dart';
import '../../core/services/translation/translation_languages.dart';
import '../../core/services/translation/translation_settings.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Réglages de la traduction des messages.
///
/// La traduction s'exécute entièrement sur l'appareil : rien ne part vers un
/// service tiers, et elle fonctionne hors ligne. En contrepartie, chaque langue
/// exige un modèle téléchargé — d'où la gestion de modèles offerte ici.
class TranslationSettingsScreen extends StatefulWidget {
  const TranslationSettingsScreen({super.key});

  @override
  State<TranslationSettingsScreen> createState() =>
      _TranslationSettingsScreenState();
}

class _TranslationSettingsScreenState extends State<TranslationSettingsScreen> {
  final TranslationModelStore _models = TranslationModelStore();

  Set<String> _downloaded = const {};
  final Set<String> _busy = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshModels();
  }

  Future<void> _refreshModels() async {
    final downloaded = await _models.downloadedTargets();
    if (!mounted) return;
    setState(() {
      _downloaded = downloaded;
      _loading = false;
    });
  }

  Future<void> _download(TranslationLanguage lang) async {
    setState(() => _busy.add(lang.code));
    var ok = false;
    try {
      ok = await _models.download(lang.code);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy.remove(lang.code));

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.modelDownloadFailed)),
      );
      return;
    }
    await _refreshModels();
    // Les messages restés en attente de ce modèle redeviennent traitables.
    await MessageTranslationService.maybeInstance?.onModelInstalled();
  }

  Future<void> _delete(TranslationLanguage lang) async {
    setState(() => _busy.add(lang.code));
    try {
      await _models.delete(lang.code);
    } catch (_) {
      // Suppression best-effort : l'état réel est relu juste après.
    }
    if (!mounted) return;
    setState(() => _busy.remove(lang.code));
    await _refreshModels();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title:
            Text(l10n.translationSection, style: context.text.headlineSmall),
      ),
      body: Consumer<TranslationSettings>(
        builder: (_, settings, __) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoTranslate),
                subtitle: Text(l10n.autoTranslateDescription),
                value: settings.auto,
                onChanged: (v) => settings.setAuto(v),
              ),
              const SizedBox(height: AppSpacing.md),

              // Argument produit autant que mention légale : c'est la
              // différence tenue par cette implémentation.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline,
                      size: 16, color: context.colors.outline),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.onDeviceTranslationNotice,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              Text(l10n.translateTo, style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<String>(
                groupValue: settings.target,
                onChanged: (v) {
                  if (v != null) settings.setTarget(v);
                },
                child: Column(
                  children: [
                    for (final lang in kTranslationTargets)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(lang.nativeName),
                        value: lang.code,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text(l10n.languageModels, style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.languageModelsDescription(kApproxModelSizeMb),
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.outline),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.modelDownloadWifiNotice,
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.outline),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...kTranslationTargets.map(_buildModelTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelTile(TranslationLanguage lang) {
    final l10n = context.l10n;
    final installed = _downloaded.contains(lang.code);
    final busy = _busy.contains(lang.code);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(lang.nativeName),
      subtitle: installed
          ? null
          : Text('$kApproxModelSizeMb Mo',
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.outline)),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () => installed ? _delete(lang) : _download(lang),
              child: Text(installed ? l10n.deleteModel : l10n.downloadModel),
            ),
    );
  }
}
