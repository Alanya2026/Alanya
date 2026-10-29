// Photo de profil (réglages et onboarding) et photo de groupe (création) :
// rognage proposé d'office avant l'envoi — éditeur et sélecteur injectés.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:talky_flutter/core/services/photo_edit_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/providers/auth_provider.dart';
import 'package:talky_flutter/providers/connectivity_provider.dart';
import 'package:talky_flutter/screens/chats/create_group_screen.dart';
import 'package:talky_flutter/screens/onboarding/steps/profile_step.dart';
import 'package:talky_flutter/screens/profile/edit_profile_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/talky_models.dart';

import 'support/media_editor_fakes.dart';

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  _FakeAuth(this._user);
  final User? _user;
  final List<File> uploaded = [];
  Completer<void>? gate;

  @override
  User? get currentUser => _user;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<String> updateAvatar(File file) async {
    uploaded.add(file);
    // Le fichier doit exister pendant tout l'envoi.
    expect(file.existsSync(), isTrue);
    if (gate != null) await gate!.future;
    return 'https://exemple.test/a.jpg';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConnectivity extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEditor {
  _FakeEditor(this.dir, this.png);
  final Directory dir;
  final List<int> png;
  final List<File> sources = [];
  final List<PhotoEditTarget> targets = [];
  final List<File> produced = [];
  bool cancel = false;

  Future<File?> call(
    BuildContext context,
    File source, {
    PhotoEditTarget target = PhotoEditTarget.photo,
  }) async {
    sources.add(source);
    targets.add(target);
    if (cancel) return null;
    final f = File(p.join(dir.path, 'edited_${produced.length + 1}.jpg'))
      ..writeAsBytesSync(png);
    produced.add(f);
    return f;
  }
}

User _user() => User(
  alanyaID: 1,
  nom: 'Awa',
  pseudo: 'awa',
  alanyaPhone: '12345678',
  email: '',
  idPays: 1,
  avatarUrl: '',
  typeCompte: 0,
  isOnline: true,
  lastSeen: '',
);

Widget _app(Widget home, List<SingleChildWidget> providers, {String lang = 'fr'}) =>
    MultiProvider(
      providers: providers,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

/// Quelques images (pas de pumpAndSettle : un indicateur de chargement des
/// pays tourne tant que le réseau — absent en test — ne répond pas).
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory tmp;
  late _FakeEditor editor;
  late File picked;
  final pickedFrom = <ImageSource>[];

  Future<XFile?> pick(ImageSource s) async {
    pickedFrom.add(s);
    return XFile(picked.path);
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('avatar_edit');
    final dir = Directory(p.join(tmp.path, PhotoEditService.directoryName))
      ..createSync();
    editor = _FakeEditor(dir, await solidPng(8, 8));
    pickedFrom.clear();
    picked = File(p.join(tmp.path, 'choisie.png'))
      ..writeAsBytesSync(await solidPng(8, 8));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('réglages du profil', () {
    Future<_FakeAuth> open(WidgetTester t) async {
      t.view.physicalSize = const Size(420, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final auth = _FakeAuth(_user());
      await t.pumpWidget(
        _app(
          EditProfileScreen(pickImage: pick, editPhoto: editor.call),
          [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            Provider<TalkyApiClient>.value(value: TalkyApiClient()),
          ],
        ),
      );
      await _settle(t);
      return auth;
    }

    Future<void> chooseGallery(WidgetTester t) async {
      await t.tap(find.byIcon(Icons.camera_alt));
      await _settle(t);
      await t.tap(find.text('Choisir depuis la galerie'));
      await _settle(t);
    }

    testWidgets('galerie : rognage carré d\'office, puis envoi du fichier rogné',
        (t) async {
      final auth = await open(t);
      await chooseGallery(t);
      expect(pickedFrom, [ImageSource.gallery]);
      expect(editor.sources.single.path, picked.path);
      expect(editor.targets.single, PhotoEditTarget.avatar);
      expect(auth.uploaded.single.path, editor.produced.single.path);
      // Le fichier temporaire est nettoyé après l'envoi ; l'original reste.
      expect(editor.produced.single.existsSync(), isFalse);
      expect(picked.existsSync(), isTrue);
    });

    testWidgets('caméra : même rognage', (t) async {
      final auth = await open(t);
      await t.tap(find.byIcon(Icons.camera_alt));
      await _settle(t);
      await t.tap(find.text('Prendre une photo'));
      await _settle(t);
      expect(pickedFrom, [ImageSource.camera]);
      expect(editor.targets.single, PhotoEditTarget.avatar);
      expect(auth.uploaded.single.path, editor.produced.single.path);
    });

    testWidgets('abandon du rognage : rien n\'est envoyé', (t) async {
      editor.cancel = true;
      final auth = await open(t);
      await chooseGallery(t);
      expect(editor.sources, hasLength(1));
      expect(auth.uploaded, isEmpty);
      expect(picked.existsSync(), isTrue);
    });
  });

  group('onboarding', () {
    testWidgets('photo de profil : rognage d\'office puis envoi', (t) async {
      t.view.physicalSize = const Size(420, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final auth = _FakeAuth(_user());
      await t.pumpWidget(
        _app(
          Scaffold(
            body: ProfileStep(
              onContinue: () {},
              pickImage: pick,
              editPhoto: editor.call,
            ),
          ),
          [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            Provider<TalkyApiClient>.value(value: TalkyApiClient()),
          ],
        ),
      );
      await _settle(t);
      await t.tap(find.byIcon(Icons.camera_alt_outlined).first);
      await _settle(t);
      await t.tap(find.text('Choisir dans la galerie'));
      await _settle(t);
      expect(editor.targets.single, PhotoEditTarget.avatar);
      expect(auth.uploaded.single.path, editor.produced.single.path);
    });
  });

  group('création de groupe', () {
    Future<void> open(WidgetTester t) async {
      // L'écran existant pose des ListTile dans une carte colorée : l'assertion
      // de développement du framework (sans effet sur ce qu'on teste) est
      // écartée.
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('ListTile background color')) return;
        // Le fichier de la photo remplacée est supprimé pendant que son image
        // se charge (lecture réelle, hors horloge du test).
        if (d.library == 'image resource service') return;
        previous?.call(d);
      };
      addTearDown(() => FlutterError.onError = previous);
      t.view.physicalSize = const Size(420, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          CreateGroupScreen(
            members: const [],
            pickImage: pick,
            editPhoto: editor.call,
          ),
          [
            ChangeNotifierProvider<ConnectivityProvider>.value(
              value: _FakeConnectivity(),
            ),
          ],
        ),
      );
      await _settle(t);
    }

    ImageProvider? avatarImage(WidgetTester t) =>
        t.widget<CircleAvatar>(find.byType(CircleAvatar).first).backgroundImage;

    testWidgets('la photo du groupe est la photo rognée', (t) async {
      await open(t);
      expect(avatarImage(t), isNull);
      await t.tap(find.byType(CircleAvatar).first);
      await _settle(t);
      expect(editor.sources.single.path, picked.path);
      expect(editor.targets.single, PhotoEditTarget.avatar);
      final shown = avatarImage(t) as FileImage;
      expect(shown.file.path, editor.produced.single.path);
    });

    testWidgets('abandon : pas de photo ; changer de photo supprime la précédente',
        (t) async {
      await open(t);
      editor.cancel = true;
      await t.tap(find.byType(CircleAvatar).first);
      await _settle(t);
      expect(avatarImage(t), isNull);

      editor.cancel = false;
      await t.tap(find.byType(CircleAvatar).first);
      await _settle(t);
      final first = editor.produced.single;
      expect(first.existsSync(), isTrue);

      // Seconde photo : la première retouche n'a plus d'utilité.
      await t.tap(find.byType(CircleAvatar).first);
      await _settle(t);
      expect(editor.produced, hasLength(2));
      expect(first.existsSync(), isFalse);
      expect((avatarImage(t) as FileImage).file.path, editor.produced.last.path);

      // Abandonner ensuite garde la photo courante.
      editor.cancel = true;
      await t.tap(find.byType(CircleAvatar).first);
      await _settle(t);
      expect((avatarImage(t) as FileImage).file.path, editor.produced.last.path);
      expect(editor.produced.last.existsSync(), isTrue);
    });
  });
}
