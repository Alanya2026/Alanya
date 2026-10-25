/// Droits d'accès Alanya Plus, tels que le serveur les calcule.
///
/// Même charge utile que `entitlements` dans `/auth/me` et que
/// `GET /billing/me` (Alanya-Backend, src/services/billing/rules.js). Le
/// téléphone ne recalcule jamais la règle : il lit ce qu'on lui donne.
library;

/// Fonctionnalités de l'offre. Le code est celui du catalogue serveur
/// (table `feature`, migration 080).
enum PlusFeature {
  translation('translation'),
  backup('backup'),
  trustedTrips('trusted_trips'),
  listRingtones('list_ringtones'),
  style('style'),
  verifiedBadge('verified_badge'),

  /// Pack Royal (stickers Plus). Le verrou est imposé par le serveur ; le
  /// catalogue dit lequel (`locked`).
  stickersPremium('stickers_premium');

  const PlusFeature(this.code);
  final String code;

  /// Depuis le code serveur (`feature` d'un refus `SUBSCRIPTION_REQUIRED`).
  static PlusFeature? fromCode(Object? code) {
    for (final f in values) {
      if (f.code == code) return f;
    }
    return null;
  }
}

/// Phase du payant : tout gratuit, grâce annoncée, ou réservé aux abonnés.
enum PlusPhase { free, grace, paid }

/// Le régime en vigueur, choisi par l'administration. Le téléphone ne code ni
/// l'un ni l'autre : il lit ce que dit le serveur.
///
///  - [plus] : Alanya Plus — des fonctionnalités annexes payantes, paiement
///    dans l'application, messages et appels ouverts à tous. C'est aussi ce que
///    suppose un serveur qui n'envoie pas de régime.
///  - [trial] : un essai gratuit, puis la réception seule jusqu'à
///    l'activation d'un code d'abonnement.
enum PlusModel { plus, trial }

PlusModel _model(Object? v) => v == 2 ? PlusModel.trial : PlusModel.plus;

PlusPhase _phase(Object? v) => switch (v) {
      'grace' => PlusPhase.grace,
      'paid' => PlusPhase.paid,
      _ => PlusPhase.free,
    };

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Une période d'abonnement (en cours, ou à venir si payée pendant la grâce).
class PlusPeriod {
  const PlusPeriod({
    this.plan,
    this.startsAt,
    this.endsAt,
    this.source = 0,
    this.autoRenew = false,
  });

  /// Code du plan (`plus_mensuel`, `plus_annuel`…).
  final String? plan;
  final DateTime? startsAt;

  /// Fin de la chaîne de périodes : un renouvellement anticipé la repousse.
  final DateTime? endsAt;

  /// 0 paiement, 1 essai, 2 offert, 3 compensation, 4 code d'activation.
  final int source;
  final bool autoRenew;

  factory PlusPeriod.fromJson(Map<String, dynamic> json) => PlusPeriod(
        plan: json['plan'] as String?,
        startsAt: _date(json['startsAt']),
        endsAt: _date(json['endsAt']),
        source: (json['source'] as num?)?.toInt() ?? 0,
        autoRenew: json['autoRenew'] == true,
      );

  Map<String, dynamic> toJson() => {
        'plan': plan,
        'startsAt': startsAt?.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'source': source,
        'autoRenew': autoRenew,
      };
}

/// Ce que le compte peut envoyer en une fois : la taille d'un fichier et le
/// nombre de médias d'un album. Le serveur les calcule selon que le compte a
/// payé ou non, et les applique — le téléphone ne fait que les lire, pour
/// refuser tôt et dire le bon plafond.
class PlusLimits {
  const PlusLimits({
    this.maxUploadBytes = kStandardUploadBytes,
    this.maxAlbumItems = kStandardAlbumItems,
    this.paid = false,
  });

  /// Palier standard : ce que fait un compte sans abonnement, et ce que suppose
  /// un serveur qui n'envoie pas de limites.
  static const standard = PlusLimits();

  final int maxUploadBytes;
  final int maxAlbumItems;

  /// Le compte a payé (palier de 200 Mo et 100 médias).
  final bool paid;

  /// Le plafond d'un fichier, en Mo entiers, pour les messages.
  int get maxUploadMb => (maxUploadBytes / (1024 * 1024)).round();

  static PlusLimits fromJson(Object? json) {
    if (json is! Map) return standard;
    int positive(Object? v, int fallback) {
      final n = v is num ? v.toInt() : int.tryParse('$v');
      return n != null && n > 0 ? n : fallback;
    }
    return PlusLimits(
      maxUploadBytes: positive(json['maxUploadBytes'], kStandardUploadBytes),
      maxAlbumItems: positive(json['maxAlbumItems'], kStandardAlbumItems),
      paid: json['tier'] == 'paid',
    );
  }

  Map<String, dynamic> toJson() => {
        'maxUploadBytes': maxUploadBytes,
        'maxAlbumItems': maxAlbumItems,
        'tier': paid ? 'paid' : 'standard',
      };
}

/// Plafonds du palier standard : 50 Mo par fichier, 30 médias par album. Les
/// mêmes que ceux du serveur (constants/billing.js, TIER_LIMITS.standard).
const int kStandardUploadBytes = 50 * 1024 * 1024;
const int kStandardAlbumItems = 30;

/// L'essai gratuit du compte (régime [PlusModel.trial]).
class PlusTrial {
  const PlusTrial({required this.endsAt, required this.active});

  /// Fin de l'essai : trois mois après l'inscription, ou la fin de la grâce
  /// pour un compte qui existait déjà à l'activation du payant.
  final DateTime endsAt;

  /// Il court encore : tout est ouvert.
  final bool active;

  static PlusTrial? fromJson(Object? json) {
    if (json is! Map) return null;
    final ends = _date(json['endsAt']);
    if (ends == null) return null;
    return PlusTrial(endsAt: ends, active: json['active'] == true);
  }

  Map<String, dynamic> toJson() => {
        'endsAt': endsAt.toUtc().toIso8601String(),
        'active': active,
      };
}

class Entitlements {
  const Entitlements({
    required this.known,
    this.model = PlusModel.plus,
    this.trial,
    this.limits = PlusLimits.standard,
    this.phase = PlusPhase.free,
    this.graceUntil,
    this.period,
    this.upcoming,
    this.exempt = false,
    this.features = const {},
    this.validUntil,
    this.lapsedAt,
    this.purgeAfter,
    this.purgedAt,
    this.verificationStatus,
    this.verifiedUntil,
  });

  /// Serveur antérieur à l'abonnement, ou droits indisponibles : tout est
  /// permis. L'app ne ferme jamais une fonctionnalité faute de réponse.
  static const unrestricted = Entitlements(known: false);

  /// Faux tant que le serveur n'a pas envoyé de droits.
  final bool known;

  /// Le régime en vigueur. Absent d'un serveur antérieur : Alanya Plus.
  final PlusModel model;

  /// L'essai du compte ; nul hors régime [PlusModel.trial], payant éteint ou
  /// pour un compte exempté.
  final PlusTrial? trial;

  /// Ce que le compte peut envoyer en une fois. Sans mention du serveur : palier
  /// standard — le téléphone ne promet jamais plus que ce qu'on lui a dit.
  final PlusLimits limits;
  final PlusPhase phase;
  final DateTime? graceUntil;
  final PlusPeriod? period;
  final PlusPeriod? upcoming;

  /// Équipe et compte officiel : jamais soumis à l'offre.
  final bool exempt;
  final Map<String, bool> features;

  /// Au-delà, redemander les droits. Ne ferme rien à lui seul : le serveur
  /// fait respecter ce qu'il voit, et un droit en cache vaut mieux qu'un
  /// verrou posé faute de réseau.
  final DateTime? validUntil;

  /// Fin du dernier abonnement, quand il est terminé et qu'aucun n'a pris le
  /// relais. Nul pour qui n'a jamais été abonné.
  final DateTime? lapsedAt;

  /// Abonnement terminé : réglages et historique payants conservés jusque-là.
  final DateTime? purgeAfter;

  /// … puis effacés côté serveur à cette date. Le téléphone efface alors ce
  /// qu'il garde de son côté (modèles de traduction, sons des listes).
  final DateTime? purgedAt;

  /// La coche telle que le serveur l'a écrite (0 non demandée, 1 en cours,
  /// 2 vérifiée, 3 refusée, 4 révoquée, 5 expirée), et jusqu'à quand elle
  /// tient. Nulle avec un serveur antérieur : le profil fait alors foi.
  final int? verificationStatus;
  final DateTime? verifiedUntil;

  /// La coche s'affiche.
  bool get isVerified => verificationStatus == 2;

  /// Une fonctionnalité inconnue du serveur n'est pas verrouillée.
  bool has(PlusFeature feature) => !known || (features[feature.code] ?? true);

  /// Le compte peut-il ENVOYER un message ou LANCER un appel ? Recevoir, lui,
  /// n'est jamais soumis à rien.
  ///
  /// Même règle que `has` : sans droits, ou avec un serveur qui ne parle pas de
  /// ce droit (`features.outgoing`), tout est permis. Le téléphone ne ferme
  /// jamais l'envoi faute de réponse — le serveur, lui, refuse pour de bon.
  bool get canSend => !known || (features['outgoing'] ?? true);

  /// Régime essai, interrupteur allumé : ce que le compte peut faire dépend de
  /// son essai et de son abonnement.
  bool get isTrialModel => known && model == PlusModel.trial;

  bool get isSubscribed => period != null;

  bool isStale(DateTime now) =>
      known && validUntil != null && now.isAfter(validUntil!);

  factory Entitlements.fromJson(Map<String, dynamic>? json) {
    if (json == null) return unrestricted;
    final raw = json['features'];
    final features = <String, bool>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is bool) features['$k'] = v;
        if (v is num) features['$k'] = v != 0;
      });
    }
    Map<String, dynamic>? map(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final period = map(json['period']);
    final upcoming = map(json['upcoming']);
    final verification = map(json['verification']);
    return Entitlements(
      known: true,
      model: _model(json['model']),
      trial: PlusTrial.fromJson(json['trial']),
      limits: PlusLimits.fromJson(json['limits']),
      phase: _phase(json['phase']),
      graceUntil: _date(json['graceUntil']),
      period: period == null ? null : PlusPeriod.fromJson(period),
      upcoming: upcoming == null ? null : PlusPeriod.fromJson(upcoming),
      exempt: json['exempt'] == true,
      features: features,
      validUntil: _date(json['validUntil']),
      lapsedAt: _date(json['lapsedAt']),
      purgeAfter: _date(json['purgeAfter']),
      purgedAt: _date(json['purgedAt']),
      verificationStatus: (verification?['status'] as num?)?.toInt(),
      verifiedUntil: _date(verification?['until']),
    );
  }

  /// Forme serveur, pour le cache local : relue par [Entitlements.fromJson].
  Map<String, dynamic> toJson() => {
        'model': model == PlusModel.trial ? 2 : 1,
        if (trial != null) 'trial': trial!.toJson(),
        'limits': limits.toJson(),
        'phase': phase.name,
        'graceUntil': graceUntil?.toUtc().toIso8601String(),
        'period': period?.toJson(),
        'upcoming': upcoming?.toJson(),
        'exempt': exempt,
        'features': features,
        'validUntil': validUntil?.toUtc().toIso8601String(),
        'lapsedAt': lapsedAt?.toUtc().toIso8601String(),
        'purgeAfter': purgeAfter?.toUtc().toIso8601String(),
        'purgedAt': purgedAt?.toUtc().toIso8601String(),
        if (verificationStatus != null)
          'verification': {
            'status': verificationStatus,
            'until': verifiedUntil?.toUtc().toIso8601String(),
          },
      };
}
