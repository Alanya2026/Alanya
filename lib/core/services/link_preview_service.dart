import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Métadonnées d'aperçu d'un lien (Open Graph).
class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String domain;

  const LinkPreviewData({
    required this.url,
    required this.domain,
    this.title,
    this.description,
    this.imageUrl,
  });

  /// Y a-t-il assez d'infos pour valoir une carte ?
  /// Le domaine seul suffit : on affiche toujours quelque chose pour un lien
  /// détecté, même si le site ne sert pas d'Open Graph.
  bool get hasContent => domain.isNotEmpty;
}

/// Récupère les métadonnées d'un lien et les met en cache **en mémoire**
/// (par URL) pour éviter de re-télécharger la page à chaque reconstruction de
/// la bulle (scroll). En cas d'échec réseau / anti-bot, on cache quand même
/// une carte domaine-seul pour ne pas réessayer en boucle.
class LinkPreviewService {
  LinkPreviewService._();

  static const _browserUa =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static final Map<String, LinkPreviewData> _cache = {};
  static final Map<String, Future<LinkPreviewData>> _inFlight = {};

  static Future<LinkPreviewData> fetch(String url) {
    final cached = _cache[url];
    if (cached != null) return Future.value(cached);
    return _inFlight.putIfAbsent(url, () => _doFetch(url));
  }

  static LinkPreviewData fallback(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    final domain = host.replaceFirst(RegExp(r'^www\.'), '');
    return LinkPreviewData(
      url: url,
      domain: domain.isNotEmpty ? domain : url,
      title: domain.isNotEmpty ? domain : url,
    );
  }

  static Future<LinkPreviewData> _doFetch(String url) async {
    final fallbackData = fallback(url);
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': _browserUa,
              'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode < 200 || res.statusCode >= 400) {
        debugPrint('[LinkPreview] HTTP ${res.statusCode} $url');
        return _remember(url, fallbackData);
      }

      // Limite le parsing aux premiers octets utiles (head / meta).
      final body = res.body.length > 512 * 1024
          ? res.body.substring(0, 512 * 1024)
          : res.body;
      final doc = html_parser.parse(body);

      String? meta(String key) =>
          doc.querySelector('meta[property="$key"]')?.attributes['content'] ??
          doc.querySelector('meta[name="$key"]')?.attributes['content'];

      final title =
          (meta('og:title') ?? doc.querySelector('title')?.text)?.trim();
      final description =
          (meta('og:description') ?? meta('description'))?.trim();
      var image = meta('og:image') ?? meta('twitter:image');

      if (image != null && image.isNotEmpty && !image.startsWith('http')) {
        image = Uri.parse(url).resolve(image).toString();
      }

      final data = LinkPreviewData(
        url: url,
        domain: fallbackData.domain,
        title: (title != null && title.isNotEmpty) ? title : fallbackData.title,
        description: (description != null && description.isNotEmpty)
            ? description
            : null,
        imageUrl: (image != null && image.isNotEmpty) ? image : null,
      );

      return _remember(url, data);
    } catch (e) {
      debugPrint('[LinkPreview] échec $url: $e');
      return _remember(url, fallbackData);
    }
  }

  static LinkPreviewData _remember(String url, LinkPreviewData data) {
    _cache[url] = data;
    _inFlight.remove(url);
    return data;
  }
}
