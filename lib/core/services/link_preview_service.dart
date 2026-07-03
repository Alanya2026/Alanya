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
  bool get hasContent => (title != null && title!.isNotEmpty) || imageUrl != null;
}

/// Récupère les métadonnées d'un lien et les met en cache **en mémoire**
/// (par URL) pour éviter de re-télécharger la page à chaque reconstruction de
/// la bulle (scroll). Un échec est aussi caché (valeur null) pour ne pas
/// réessayer en boucle. Le cache est vidé au redémarrage de l'app.
class LinkPreviewService {
  LinkPreviewService._();

  static final Map<String, LinkPreviewData?> _cache = {};
  static final Map<String, Future<LinkPreviewData?>> _inFlight = {};

  static Future<LinkPreviewData?> fetch(String url) {
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    // Déduplique les requêtes simultanées sur la même URL.
    return _inFlight.putIfAbsent(url, () => _doFetch(url));
  }

  static Future<LinkPreviewData?> _doFetch(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; TalkyBot/1.0)'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return _remember(url, null);

      final doc = html_parser.parse(res.body);

      String? meta(String key) =>
          doc.querySelector('meta[property="$key"]')?.attributes['content'] ??
          doc.querySelector('meta[name="$key"]')?.attributes['content'];

      final title = (meta('og:title') ?? doc.querySelector('title')?.text)?.trim();
      final description = (meta('og:description') ?? meta('description'))?.trim();
      var image = meta('og:image') ?? meta('twitter:image');

      // Résout une image en chemin relatif contre l'URL de base.
      if (image != null && image.isNotEmpty && !image.startsWith('http')) {
        image = Uri.parse(url).resolve(image).toString();
      }

      final data = LinkPreviewData(
        url: url,
        domain: Uri.parse(url).host.replaceFirst('www.', ''),
        title: (title != null && title.isNotEmpty) ? title : null,
        description: (description != null && description.isNotEmpty) ? description : null,
        imageUrl: (image != null && image.isNotEmpty) ? image : null,
      );

      return _remember(url, data.hasContent ? data : null);
    } catch (e) {
      debugPrint('[LinkPreview] échec $url: $e');
      return _remember(url, null);
    }
  }

  static LinkPreviewData? _remember(String url, LinkPreviewData? data) {
    _cache[url] = data;
    _inFlight.remove(url);
    return data;
  }
}
