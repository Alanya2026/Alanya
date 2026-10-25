import 'dart:convert';

import '../../l10n/app_localizations.dart';
import '../theme/locale_controller.dart';

/// Type de message porteur d'un sticker (`type = 10`).
///
/// Les types 0-9 sont pris (texte, médias, localisation, système, contact,
/// bienvenue, trajet). `content` porte un JSON versionné ; `mediaUrl` est
/// recalculée par le serveur ; `mediaName` vaut « Sticker 😂 » (repli lisible
/// pour les anciens APK). Contrat : `docs-stickers/contract/CONTRAT-STICKERS.md`.
const int kStickerMessageType = 10;

/// Plus grand entier exact côté JSON (2^53).
const int _kSidMax = 9007199254740992;

/// Contenu d'un message de type 10.
///
/// `tryParse` est **tolérant** : jamais d'exception, `null` si le contenu n'est
/// pas un objet JSON exploitable. Une version inconnue (`v` > 1) renvoie une
/// charge « repli » (`isRenderable == false`) : l'appelant affiche « Sticker »
/// + l'emoji, jamais le JSON.
class StickerPayload {
  /// Version que ce client sait lire.
  static const int currentVersion = 1;

  /// Octets maximum de `content` (limite du contrat).
  static const int maxContentBytes = 512;

  const StickerPayload({
    required this.version,
    required this.pack,
    required this.sid,
    required this.emoji,
    this.w = 512,
    this.h = 512,
    this.animated = false,
  });

  final int version;
  final String pack;

  /// Identifiant du sticker ; `null` pour une version future illisible.
  final int? sid;

  /// Emoji associé, `''` si absent ou illisible.
  final String emoji;
  final int w;
  final int h;
  final bool animated;

  /// `true` si ce client sait afficher l'image (version connue, `sid` valide).
  bool get isRenderable => version == currentVersion && sid != null;

  /// Libellé d'accessibilité / d'aperçu : « 😂 » + libellé localisé.
  String labelWith(String stickerWord) =>
      emoji.isEmpty ? stickerWord : '$emoji $stickerWord';

  /// Forme canonique (celle que le serveur réécrit). Le serveur ignore `w`,
  /// `h`, `a`, `emoji` envoyés : seul `sid` fait foi.
  String encode() => jsonEncode(<String, dynamic>{
        'v': currentVersion,
        'pack': pack,
        'sid': sid,
        'emoji': emoji,
        'w': w,
        'h': h,
        'a': animated ? 1 : 0,
      });

  static StickerPayload? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final data = jsonDecode(content);
      if (data is! Map) return null;
      final v = _asInt(data['v']);
      if (v == null || v < 1) return null;
      final emoji = _cleanEmoji(data['emoji']);
      final pack = data['pack'] is String ? (data['pack'] as String) : '';
      final sid = _asSid(data['sid']);
      if (v == currentVersion) {
        if (sid == null || pack.isEmpty) return null;
      }
      return StickerPayload(
        version: v,
        pack: pack,
        sid: v == currentVersion ? sid : null,
        emoji: emoji,
        w: _asDim(data['w']),
        h: _asDim(data['h']),
        animated: data['a'] == 1 || data['a'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Emoji lisible même si le reste du payload est inexploitable (repli).
  static String emojiOf(String? content) =>
      tryParse(content)?.emoji ?? '';

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is double && v.isFinite && v == v.truncateToDouble()) {
      return v.toInt();
    }
    return null;
  }

  static int? _asSid(Object? v) {
    final n = _asInt(v);
    if (n == null || n <= 0 || n > _kSidMax) return null;
    return n;
  }

  static int _asDim(Object? v) {
    final n = _asInt(v);
    return (n == null || n <= 0 || n > 4096) ? 512 : n;
  }

  static String _cleanEmoji(Object? v) {
    if (v is! String) return '';
    final s = v.trim();
    if (s.isEmpty || s.runes.length > 16) return '';
    return s;
  }
}

/// Aperçu lisible d'un message sticker (liste des conversations, citation,
/// transfert, notification) : « 😂 Sticker ». **Jamais** le JSON, même si
/// `content` est cassé ou d'une version future.
String stickerPreviewLabel(String? content, {AppLocalizations? l10n}) {
  final l = l10n ?? LocaleController.instance.l10n;
  final emoji = StickerPayload.emojiOf(content);
  return emoji.isEmpty ? l.stickerWord : l.stickerPreview(emoji);
}

/// Texte d'une citation (`replyToContent`) : si le serveur a recopié le JSON
/// d'un sticker cité, on le remplace par « 😂 Sticker ». Tout autre texte
/// passe tel quel.
String sanitizeQuotedContent(String text, {AppLocalizations? l10n}) {
  if (!text.startsWith('{')) return text;
  if (StickerPayload.tryParse(text) == null) return text;
  return stickerPreviewLabel(text, l10n: l10n);
}
