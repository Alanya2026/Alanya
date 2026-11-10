import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';

import 'desktop_api.dart';

/// L'état du coffre pour les écrans : espace, dossiers racines, albums
/// récents, aperçus.
class Vault extends ChangeNotifier {
  Vault(this.api) : previews = SafeboxPreviewCache(transport: ApiSafeboxDownloadTransport(api));

  final DesktopApi api;
  final SafeboxPreviewCache previews;

  SafeboxOverview? _overview;
  List<SafeboxRecentAlbum> _albums = const [];
  Object? _error;
  bool _loading = false;

  SafeboxOverview? get overview => _overview;
  List<SafeboxRecentAlbum> get recentAlbums => _albums;
  Object? get error => _error;
  bool get loading => _loading;

  int? rootId(SafeboxRoot r) => _overview?.rootIds[r];

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final o = await api.fetchSafebox();
      _overview = o;
      _error = null;
      try {
        _albums = await api.fetchSafeboxRecentAlbums(limit: 4);
      } catch (_) {
        _albums = const [];
      }
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SafeboxFolderPage> folder(int id, {int? cursor}) => api.fetchSafeboxFolder(id, cursor: cursor);

  void clear() {
    _overview = null;
    _albums = const [];
    _error = null;
    notifyListeners();
  }
}
