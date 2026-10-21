import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/document_file_style.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Pièces jointes : le type MIME annoncé au serveur (qui filtre par type), et
/// l'icône de la bulle document, pour les extensions ajoutées le 21/10/2026.
void main() {
  // Les libellés traduits (Photo, Agenda…) passent par l'instance courante.
  TestWidgetsFlutterBinding.ensureInitialized();
  late final TalkyApiClient api;
  setUpAll(() {
    LocaleController();
    api = TalkyApiClient();
  });

  String mime(String name) => api.mimeTypeForPath('/tmp/$name').mimeType;

  test('Office à macros et diaporamas : un type précis, pas octet-stream', () {
    expect(mime('cours.pptm'),
        'application/vnd.ms-powerpoint.presentation.macroenabled.12');
    expect(mime('rapport.docm'),
        'application/vnd.ms-word.document.macroenabled.12');
    expect(mime('budget.xlsm'), 'application/vnd.ms-excel.sheet.macroenabled.12');
    expect(mime('expo.ppsx'),
        'application/vnd.openxmlformats-officedocument.presentationml.slideshow');
  });

  test('archives gz : repli par extension', () {
    expect(mime('sources.tar.gz'), 'application/gzip');
    expect(mime('sources.tgz'), 'application/gzip');
    expect(mime('sources.tar'), 'application/x-tar');
  });

  test('famille de la bulle document', () {
    String family(String name) => DocumentFileStyle.fromFileName(name).family;
    expect(family('cours.pptm'), 'powerpoint');
    expect(family('expo.pps'), 'powerpoint');
    expect(family('rapport.docm'), 'word');
    expect(family('budget.xlsb'), 'excel');
    expect(family('schema.odg'), 'opendocument');
    expect(family('livre.epub'), 'ebook');
    expect(family('photo.HEIC'), 'image');
    expect(family('film.mkv'), 'video');
    expect(family('son.aiff'), 'audio');
    expect(family('contact.vcf'), 'contact');
    expect(family('rdv.ics'), 'calendar');
    expect(family('sources.tgz'), 'archive');
    expect(family('notes.md'), 'text');
    expect(family('inconnu.xyz'), 'other');
    expect(DocumentFileStyle.fromFileName('cours.pptm').extension, 'PPTM');
  });
}
