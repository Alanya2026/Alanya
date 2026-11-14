import 'dart:io';
import 'dart:typed_data';

import 'package:alanya_coffre/core/desktop_api.dart';
import 'package:alanya_coffre/core/session_store.dart';
import 'package:alanya_coffre/core/vault.dart';
import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Envois implements SafeboxJobStore {
  @override
  Future<List<SafeboxUploadJob>> loadJobs() async => const [];
  @override
  Future<void> saveJobs(List<SafeboxUploadJob> jobs) async {}
  @override
  Future<Uint8List?> loadKey(String jobId) async => null;
  @override
  Future<void> saveKey(String jobId, Uint8List key) async {}
  @override
  Future<void> deleteKey(String jobId) async {}
}

void main() {
  test('les fichiers gardés passent sous la limite, les plus anciens d’abord, jamais un téléchargement en cours', () async {
    SharedPreferences.setMockInitialValues({});
    final tmp = Directory.systemTemp.createTempSync('coffre_garde');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File garder(int id, String nom, int octets, int ilYaHeures) {
      final f = File('${tmp.path}/files/$id/$nom')
        ..createSync(recursive: true)
        ..writeAsBytesSync(Uint8List(octets));
      f.setLastModifiedSync(DateTime.now().subtract(Duration(hours: ilYaHeures)));
      return f;
    }

    final vieux = garder(1, 'vieux.mp4', 400, 30);
    final partiel = garder(2, 'film.mp4.part', 400, 40); // en cours, le plus ancien
    final moyen = garder(3, 'moyen.jpg', 300, 10);
    final recent = garder(4, 'recent.jpg', 300, 1);

    final vault = Vault(DesktopApi(store: SessionStore()), baseDir: () async => tmp, jobStore: _Envois());
    addTearDown(vault.dispose);
    await vault.trimKept(); // celui du démarrage (1 Go) : rien à faire
    await vault.trimKept(maxBytes: 1000); // 1 400 octets gardés, cible 750

    expect(vieux.existsSync(), isFalse);
    expect(moyen.existsSync(), isFalse);
    expect(partiel.existsSync(), isTrue);
    expect(recent.existsSync(), isTrue);
  });
}
