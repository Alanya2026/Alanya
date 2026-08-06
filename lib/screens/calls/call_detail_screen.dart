import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../core/utils/country_utils.dart';
import '../../core/services/call_service.dart';
import '../../core/services/local_cache_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../core/utils/conversation_display.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/contact_action_button.dart';
import '../chats/chat_detail_screen.dart';

/// Fiche d'un appel récent : récap de l'appel + raccourcis rapides
/// (appel audio, vidéo, message, contact préféré).
class CallDetailScreen extends StatefulWidget {
  const CallDetailScreen({
    super.key,
    required this.user,
    required this.call,
  });

  /// Le correspondant (l'autre participant de l'appel).
  final User user;

  /// L'appel sélectionné (pour le récapitulatif).
  final Call call;

  @override
  State<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends State<CallDetailScreen> {
  late final TalkyApiClient _api;
  String _phone = '';
  String _paysLibelle = '';
  bool _isFavorite = false;
  bool _busy = false;

  int get _userId => widget.user.alanyaID;
  String get _displayName =>
      widget.user.nom.isNotEmpty ? widget.user.nom : widget.user.pseudo;

  @override
  void initState() {
    super.initState();
    _api = Provider.of<TalkyApiClient>(context, listen: false);
    _phone = widget.user.alanyaPhone;
    _paysLibelle = widget.user.paysLibelle ?? '';
    _load();
  }

  Future<void> _load() async {
    final favorite = await _api.checkIsContact(_userId).catchError((_) => false);
    final full = await _api.getUserById(_userId).catchError((_) => <String, dynamic>{});
    if (!mounted) return;
    setState(() {
      _isFavorite = favorite;
      if (full['alanyaPhone'] != null) _phone = full['alanyaPhone'];
      if (full['pays_libelle'] != null) _paysLibelle = full['pays_libelle'];
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _initiateCall({required bool isVideo}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: _userId,
      myId: auth.currentUser?.alanyaID ?? 0,
      myName: auth.currentUser?.nom ?? '',
      myPhoto: auth.currentUser?.avatarUrl,
      targetUserName: _displayName,
      targetUserPhoto: widget.user.avatarUrl,
      isVideo: isVideo,
    );
    if (!mounted) return;
    if (callService.errorMessage != null) {
      _snack(callService.errorMessage!, error: true);
      return;
    }
    await callService.navigateToCallUi(context);
  }

  Future<void> _openMessage() async {
    // Depuis un appel récent, retrouver la discussion 1-1 existante
    // pour ouvrir l'historique (sinon ChatDetailScreen reste vide).
    int? convId;
    final myId = context.read<AuthProvider>().currentUser?.alanyaID;
    if (myId != null) {
      final convs =
          await context.read<ChatProvider>().repository.dao.getAllConversations();
      convId = findLocalDirectConversationId(convs, myId, _userId);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: _displayName,
          conversationId: convId,
          userId: _userId,
          avatarUrl: widget.user.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;
    setState(() => _busy = true);
    final next = !_isFavorite;
    try {
      if (next) {
        await _api.addContact(_userId);
      } else {
        // Passe par le cache : retirer des favoris doit aussi sortir le
        // contact de toutes les listes où il figure.
        await context.read<LocalCacheRepository>().removePreferredContact(_userId);
      }
      if (mounted) setState(() => _isFavorite = next);
    } catch (e) {
      _snack(context.l10n.actionFailedWithError('$e'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.user.avatarUrl;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
      ),
      body: ListView(
        children: [
          AppSpacing.vGapSm,
          // En-tête : photo + nom + identifiants
          Column(
            children: [
              AppAvatar(imageUrl: avatar, name: _displayName, size: 112),
              AppSpacing.vGapMd,
              Text(_displayName, style: context.text.headlineMedium),
              if (widget.user.pseudo.isNotEmpty) ...[
                AppSpacing.vGapXs,
                Text(
                  '@${widget.user.pseudo}',
                  style: context.text.bodyLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (_phone.isNotEmpty) ...[
                AppSpacing.vGapSm,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.badge_outlined,
                        size: AppIconSize.sm, color: context.colors.primary),
                    AppSpacing.hGapXs,
                    AlanyaPhoneText(
                      _phone,
                      style: context.text.bodyMedium
                          ?.copyWith(color: context.colors.primary),
                    ),
                  ],
                ),
              ],
              if (_paysLibelle.isNotEmpty) ...[
                AppSpacing.vGapXs,
                CountryRow(country: _paysLibelle),
              ],
            ],
          ),
          AppSpacing.vGapXxl,
          // Raccourcis rapides
          Padding(
            padding: AppSpacing.screenH,
            child: Row(
              children: [
                ContactActionButton(
                    icon: Icons.call,
                    label: context.l10n.callNoun,
                    onTap: () => _initiateCall(isVideo: false)),
                AppSpacing.hGapSm,
                ContactActionButton(
                    icon: Icons.videocam,
                    label: context.l10n.video2,
                    onTap: () => _initiateCall(isVideo: true)),
                AppSpacing.hGapSm,
                ContactActionButton(
                    icon: Icons.sms_outlined,
                    label: context.l10n.messageNoun,
                    onTap: _openMessage),
                AppSpacing.hGapSm,
                ContactActionButton(
                  icon: _isFavorite ? Icons.star : Icons.star_border,
                  label: _isFavorite ? context.l10n.favoriteSingular : context.l10n.add,
                  color: _isFavorite
                      ? context.semantic.warning
                      : context.colors.primary,
                  onTap: _toggleFavorite,
                ),
              ],
            ),
          ),
          AppSpacing.vGapXxl,
          _buildCallInfo(),
        ],
      ),
    );
  }

  Widget _buildCallInfo() {
    final c = widget.call;
    final missed = c.isMissed;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: AppSpacing.screenH,
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: isDark
            ? context.colors.surfaceContainerHigh
            : context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: isDark ? null : AppShadows.subtle,
        border: isDark
            ? Border.all(color: context.colors.outline.withValues(alpha: 0.55))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.lastCall, style: context.text.titleMedium),
          AppSpacing.vGapMd,
          _infoRow(
            icon: missed ? Icons.call_missed : Icons.call_made,
            iconColor: missed ? context.colors.error : context.semantic.online,
            label: c.statusLabel,
          ),
          AppSpacing.vGapSm,
          _infoRow(
            icon: c.isVideo ? Icons.videocam : Icons.call,
            iconColor: context.colors.primary,
            label: c.isVideo ? context.l10n.videoCall : context.l10n.audioCall,
          ),
          AppSpacing.vGapSm,
          _infoRow(
            icon: Icons.schedule,
            iconColor: context.colors.onSurfaceVariant,
            label: _formatDate(c.createdAt),
          ),
          if (c.duree != null && c.duree! > 0) ...[
            AppSpacing.vGapSm,
            _infoRow(
              icon: Icons.timer_outlined,
              iconColor: context.colors.onSurfaceVariant,
              label: context.l10n.durationLabel(c.formattedDuration),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: iconColor),
        AppSpacing.hGapSm,
        Text(label, style: context.text.bodyMedium),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final hm = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        return context.l10n.todayAtTime(hm);
      }
      return context.l10n.dateAtTimeFull(date.day, date.month, date.year, hm);
    } catch (_) {
      return context.l10n.recently;
    }
  }
}
