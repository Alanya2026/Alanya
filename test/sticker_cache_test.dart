// StickerCache : préchargement Wi-Fi seulement, plafond déclaré.
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/connectivity_service.dart';
import 'package:talky_flutter/core/services/media_download_preferences.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';

class _FakeManager extends Fake implements CacheManager {
  final downloaded = <String>[];
  @override
  Future<FileInfo?> getFileFromCache(String key,
          {bool ignoreMemCache = false}) async =>
      null;
  @override
  Future<FileInfo> downloadFile(String url,
      {String? key, Map<String, String>? authHeaders, bool force = false}) async {
    downloaded.add(url);
    throw Exception('pas de réseau dans le test');
  }
}

class _Net extends ConnectivityService {
  _Net(this.unmetered);
  final bool unmetered;
  @override
  Future<bool> get currentIsUnmetered async => unmetered;
}

void main() {
  test('plafond et durée de vie déclarés', () {
    expect(StickerCache.maxObjects, 600);
    expect(StickerCache.stalePeriod, const Duration(days: 60));
  });

  test('préchargement : rien hors Wi-Fi', () async {
    final m = _FakeManager();
    final c = StickerCache(manager: m, canPrefetch: () async => false);
    expect(await c.prefetchThumbs(['a', 'b']), 0);
    expect(m.downloaded, isEmpty);
  });

  test('préchargement : Wi-Fi, échecs unitaires ignorés', () async {
    final m = _FakeManager();
    final c = StickerCache(manager: m, canPrefetch: () async => true);
    expect(await c.prefetchThumbs(['a', '', 'b']), 2);
    expect(m.downloaded, ['a', 'b']);
  });

  test('câblage media_download_preferences : Wi-Fi seulement', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(
        await MediaDownloadPreferences.shouldPrefetchStickersNow(
            connectivity: _Net(true)),
        isTrue);
    expect(
        await MediaDownloadPreferences.shouldPrefetchStickersNow(
            connectivity: _Net(false)),
        isFalse);
  });
}
