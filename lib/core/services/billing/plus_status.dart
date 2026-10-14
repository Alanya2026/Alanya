/// Où en est le compte vis-à-vis d'Alanya Plus : ce que racontent la carte du
/// profil et « Mon abonnement ». Tout se déduit des droits déjà reçus avec
/// `/auth/me` — afficher le profil ne coûte aucun appel.
library;

import 'entitlements.dart';

enum PlusStatus {
  /// Droits inconnus, compte exempté, ou interrupteur éteint : rien à montrer.
  hidden,

  /// Payant annoncé, pas encore d'abonnement.
  grace,

  /// Abonnement payé pendant la grâce : il commence à la fin de celle-ci.
  scheduled,

  /// Payant, pas d'abonnement.
  upgrade,

  /// Abonnement en cours.
  active,

  /// Abonnement terminé, rien n'a pris le relais.
  lapsed,

  /// Régime essai : l'essai gratuit court, tout est ouvert.
  trial,

  /// Régime essai : l'essai est fini et aucun abonnement n'a pris le relais.
  /// Le compte reçoit messages et appels, il ne peut ni envoyer ni appeler.
  restricted,
}

PlusStatus plusStatusOf(Entitlements e) {
  if (!e.known || e.exempt) return PlusStatus.hidden;
  // Interrupteur éteint : aucune trace de l'offre, même pour qui a déjà une
  // période (offerte avant l'activation, par ex.).
  if (e.phase == PlusPhase.free) return PlusStatus.hidden;
  if (e.period != null) return PlusStatus.active;
  if (e.upcoming != null) return PlusStatus.scheduled;
  // Régime essai : l'essai court, ou il est fini. Un abonnement qui a pris fin
  // reste « terminé » — c'est une autre histoire que « jamais abonné ».
  if (e.isTrialModel) {
    if (e.trial?.active == true) return PlusStatus.trial;
    return e.lapsedAt != null ? PlusStatus.lapsed : PlusStatus.restricted;
  }
  return switch (e.phase) {
    PlusPhase.grace => PlusStatus.grace,
    PlusPhase.paid =>
      e.lapsedAt != null ? PlusStatus.lapsed : PlusStatus.upgrade,
    PlusPhase.free => PlusStatus.hidden,
  };
}

/// Jours restants avant [until], arrondis au-dessus : « encore 1 jour »
/// jusqu'à la dernière heure, jamais « encore 0 jour ».
int plusDaysLeft(DateTime until, DateTime now) {
  final hours = until.difference(now).inHours;
  return hours <= 0 ? 0 : (hours / 24).ceil();
}

/// L'échéance entre-t-elle dans la fenêtre de relance ? Sept jours pour un
/// abonnement au mois, trente au-delà — les mêmes seuils que les relances
/// envoyées par le serveur (plan.reminder_days).
bool plusEndsSoon(PlusPeriod period, DateTime now) {
  final end = period.endsAt;
  if (end == null) return false;
  final start = period.startsAt;
  final long = start != null && end.difference(start).inDays > 45;
  return plusDaysLeft(end, now) <= (long ? 30 : 7);
}

/// Début de la période qu'un paiement fait maintenant ouvrirait.
///
/// Même règle que le serveur : à la suite de l'abonnement en cours ou à
/// venir (renouveler en avance ne fait rien perdre), jamais avant la fin de
/// la grâce (les jours gratuits annoncés sont préservés), et jamais avant la
/// fin de l'essai du compte (payer pendant l'essai ne le consomme pas).
DateTime plusNextPeriodStart(Entitlements e, DateTime now) {
  var start = now;
  for (final d in [
    e.period?.endsAt,
    e.upcoming?.endsAt,
    if (e.phase == PlusPhase.grace) e.graceUntil,
    if (e.isTrialModel && e.trial?.active == true) e.trial!.endsAt,
  ]) {
    if (d != null && d.isAfter(start)) start = d;
  }
  return start;
}

/// [date] plus [months] mois, le jour ramené à la fin du mois s'il n'existe
/// pas (31 janvier + 1 mois = 28 ou 29 février).
DateTime plusAddMonths(DateTime date, int months) {
  final utc = date.toUtc();
  final monthIndex = utc.month - 1 + months;
  final year = utc.year + (monthIndex ~/ 12);
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  final day = utc.day > lastDay ? lastDay : utc.day;
  return DateTime.utc(
    year,
    month,
    day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
  );
}
