/// Catalogue des langues de traduction et gestion des modèles ML Kit.
///
/// ML Kit sait traduire une soixantaine de langues, mais les exposer toutes
/// dans un sélecteur en fait une liste illisible. On en propose un
/// sous-ensemble ordonné par pertinence pour ALANYA, tout en acceptant
/// **n'importe quelle** langue supportée en *source* : c'est l'identification
/// automatique qui la détermine, l'utilisateur n'a rien à déclarer.
library;

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Une langue proposée comme cible de traduction.
class TranslationLanguage {
  /// Code BCP-47 — la même forme que celle renvoyée par `LanguageIdentifier`
  /// et que celle attendue par `ModelManager` (qui prend une chaîne, pas
  /// l'énumération).
  final String code;

  /// Langue ML Kit correspondante.
  final TranslateLanguage mlKit;

  /// Nom de la langue **dans cette langue**.
  ///
  /// Volontairement hors des fichiers ARB : dans un sélecteur de langue, on
  /// cherche « 中文 » ou « Português », pas « Chinois » ou « Portugais ». Un
  /// utilisateur perdu dans une interface qu'il ne lit pas doit pouvoir
  /// retrouver la sienne.
  final String nativeName;

  const TranslationLanguage(this.code, this.mlKit, this.nativeName);
}

/// Taille indicative d'un modèle de langue, en mégaoctets.
///
/// ML Kit n'expose pas la taille réelle avant téléchargement. La valeur sert
/// uniquement à prévenir l'utilisateur de l'ordre de grandeur avant de
/// consommer ses données — ne jamais la présenter comme exacte.
const int kApproxModelSizeMb = 30;

/// Langues de l'interface ALANYA. La cible de traduction par défaut d'un
/// utilisateur est celle-ci ; les autres restent accessibles au sélecteur.
const List<String> kAppLocales = ['fr', 'en', 'zh'];

/// Langues proposées comme cible de traduction.
///
/// Les trois langues de l'app d'abord, puis les langues les plus probables
/// dans les conversations. Une langue n'a pas besoin de figurer ici pour être
/// *détectée* en source — le catalogue ne gouverne que ce que l'utilisateur
/// peut choisir de lire.
const List<TranslationLanguage> kTranslationTargets = [
  TranslationLanguage('fr', TranslateLanguage.french, 'Français'),
  TranslationLanguage('en', TranslateLanguage.english, 'English'),
  TranslationLanguage('zh', TranslateLanguage.chinese, '中文'),
  TranslationLanguage('ar', TranslateLanguage.arabic, 'العربية'),
  TranslationLanguage('es', TranslateLanguage.spanish, 'Español'),
  TranslationLanguage('pt', TranslateLanguage.portuguese, 'Português'),
  TranslationLanguage('tr', TranslateLanguage.turkish, 'Türkçe'),
  TranslationLanguage('sw', TranslateLanguage.swahili, 'Kiswahili'),
  TranslationLanguage('de', TranslateLanguage.german, 'Deutsch'),
  TranslationLanguage('it', TranslateLanguage.italian, 'Italiano'),
  TranslationLanguage('nl', TranslateLanguage.dutch, 'Nederlands'),
  TranslationLanguage('ru', TranslateLanguage.russian, 'Русский'),
  TranslationLanguage('hi', TranslateLanguage.hindi, 'हिन्दी'),
  TranslationLanguage('ur', TranslateLanguage.urdu, 'اردو'),
];

/// Index BCP-47 → langue ML Kit, construit sur **toutes** les langues
/// supportées et pas seulement sur les cibles proposées : une langue source
/// détectée automatiquement peut sortir du catalogue ci-dessus.
final Map<String, TranslateLanguage> _byBcpCode = {
  for (final l in TranslateLanguage.values) l.bcpCode: l,
};

/// Résout un code BCP-47 en langue ML Kit, ou `null` si non traduisible.
///
/// Tolère les étiquettes composées que renvoie l'identification
/// (`pt-BR`, `zh-Hans`) en ne gardant que la sous-étiquette primaire.
///
/// Un cas mérite un traitement à part : `zh-Latn` désigne du chinois
/// **romanisé** (pinyin en caractères latins). Réduit à `zh`, il serait confié
/// au traducteur chinois, qui n'y reconnaîtrait rien. Mieux vaut le déclarer
/// non traduisible que produire du charabia.
TranslateLanguage? mlKitLanguageOf(String? bcpTag) {
  if (bcpTag == null) return null;
  final tag = bcpTag.trim();
  if (tag.isEmpty || tag == 'und') return null;
  if (tag.toLowerCase().contains('-latn')) return null;

  final primary = tag.split(RegExp('[-_]')).first.toLowerCase();
  return _byBcpCode[primary];
}

/// Nom natif d'une langue à partir de son code, pour le libellé
/// « traduit de … ». Retombe sur le code lui-même hors catalogue : mieux vaut
/// afficher « traduit de ko » qu'un libellé vide.
String nativeNameOf(String bcpCode) {
  final primary = bcpCode.split(RegExp('[-_]')).first.toLowerCase();
  for (final l in kTranslationTargets) {
    if (l.code == primary) return l.nativeName;
  }
  return primary;
}

/// Gestion des modèles de langue téléchargés sur l'appareil.
///
/// Enveloppe mince sur [OnDeviceTranslatorModelManager], dont l'API prend et
/// renvoie des **codes BCP-47 en chaîne**, jamais l'énumération.
class TranslationModelStore {
  final OnDeviceTranslatorModelManager _manager =
      OnDeviceTranslatorModelManager();

  Future<bool> isDownloaded(String bcpCode) =>
      _manager.isModelDownloaded(bcpCode);

  /// Wi-Fi exigé par défaut : un modèle pèse une trentaine de mégaoctets, et
  /// le déclencheur est souvent l'arrivée d'un message — on ne consomme pas le
  /// forfait de quelqu'un sans qu'il l'ait voulu.
  Future<bool> download(String bcpCode, {bool wifiOnly = true}) =>
      _manager.downloadModel(bcpCode, isWifiRequired: wifiOnly);

  Future<bool> delete(String bcpCode) => _manager.deleteModel(bcpCode);

  /// Codes des modèles présents sur l'appareil, parmi les cibles proposées.
  ///
  /// ML Kit n'offre aucun inventaire : il faut interroger chaque modèle un par
  /// un. La liste est courte et les appels sont locaux, mais c'est la raison
  /// pour laquelle on n'énumère pas les ~59 langues.
  Future<Set<String>> downloadedTargets() async {
    final results = await Future.wait(
      kTranslationTargets.map(
        (l) => isDownloaded(l.code).then((ok) => ok ? l.code : null),
      ),
    );
    return results.whereType<String>().toSet();
  }
}
