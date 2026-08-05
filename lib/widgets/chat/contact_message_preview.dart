import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/contact_payload.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../common/common.dart';

/// Carte contact dans une bulle : avatar, nom, téléphone + bouton Ajouter.
class ContactMessagePreview extends StatefulWidget {
  const ContactMessagePreview({
    super.key,
    required this.contact,
    this.isMe = false,
    this.width = 240,
    this.onOpenDetail,
  });

  final ContactPayload contact;
  final bool isMe;
  final double width;
  final VoidCallback? onOpenDetail;

  @override
  State<ContactMessagePreview> createState() => _ContactMessagePreviewState();
}

class _ContactMessagePreviewState extends State<ContactMessagePreview> {
  bool _adding = false;
  bool? _isPreferred;
  int _typeCompte = 0;
  int _accountType = 0;
  int _verificationStatus = 0;

  User get _asUser => User(
        alanyaID: widget.contact.alanyaID,
        nom: widget.contact.nom,
        pseudo: widget.contact.pseudo ?? '',
        alanyaPhone: widget.contact.alanyaPhone ?? '',
        email: '',
        idPays: 0,
        avatarUrl: widget.contact.avatarUrl ?? '',
        typeCompte: _typeCompte,
        accountType: _accountType,
        verificationStatus: _verificationStatus,
        isOnline: false,
        lastSeen: '',
      );

  @override
  void initState() {
    super.initState();
    _loadPreferred();
  }

  Future<void> _loadPreferred() async {
    final myId =
        context.read<AuthProvider>().currentUser?.alanyaID ?? 0;
    if (widget.contact.alanyaID == myId) {
      if (mounted) setState(() => _isPreferred = true);
      return;
    }
    final cache = context.read<LocalCacheRepository>();
    final api = context.read<TalkyApiClient>();
    final local = await cache.getKnownUserSocle(widget.contact.alanyaID);
    if (local != null && mounted) {
      setState(() {
        _isPreferred = local.isPreferredContact;
        _typeCompte = local.typeCompte;
        _accountType = local.accountType;
        _verificationStatus = local.verificationStatus;
      });
      if (local.isPreferredContact) return;
    }
    try {
      final fav = await api.checkIsContact(widget.contact.alanyaID);
      if (!mounted) return;
      setState(() => _isPreferred = fav);
      if (fav) {
        await cache.upsertKnownUser(_asUser, preferred: true, partial: true);
      }
    } catch (e, st) {
      AppLog.e('ContactPreview', 'checkIsContact échoué', e, st);
      if (mounted && _isPreferred == null) {
        setState(() => _isPreferred = false);
      }
    }
  }

  Future<void> _addPreferred() async {
    if (_adding || _isPreferred == true) return;
    final api = context.read<TalkyApiClient>();
    final cache = context.read<LocalCacheRepository>();
    setState(() => _adding = true);
    try {
      await api.addContact(widget.contact.alanyaID);
      await cache.upsertKnownUser(_asUser, preferred: true, partial: true);
      if (!mounted) return;
      setState(() {
        _isPreferred = true;
        _adding = false;
      });
    } catch (e, st) {
      AppLog.e('ContactPreview', 'addContact échoué', e, st);
      if (!mounted) return;
      setState(() => _adding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.unableToAddThisContactTry),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final phone = AlanyaPhoneFormatter.formatDisplay(contact.alanyaPhone);
    final showAdd = _isPreferred == false;
    final titleColor =
        widget.isMe ? context.colors.onPrimary : context.colors.onSurface;
    final muted = widget.isMe
        ? context.colors.onPrimary.withAlpha(180)
        : context.colors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpenDetail,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: widget.width,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      imageUrl: (contact.avatarUrl != null &&
                              contact.avatarUrl!.isNotEmpty)
                          ? contact.avatarUrl
                          : null,
                      name: contact.displayLabel,
                      size: AppSizes.avatarLg,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (showAdd) ...[
                  AppSpacing.vGapSm,
                  SizedBox(
                    height: 36,
                    child: widget.isMe
                        ? OutlinedButton(
                            onPressed: _adding ? null : _addPreferred,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.onPrimary,
                              side: BorderSide(
                                color: context.colors.onPrimary.withAlpha(160),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                            ),
                            child: _adding
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.onPrimary,
                                    ),
                                  )
                                : Text(context.l10n.add),
                          )
                        : FilledButton.tonal(
                            onPressed: _adding ? null : _addPreferred,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                            ),
                            child: _adding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(context.l10n.add),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
