/// Rôle restart mesh : userId le plus bas initie (anti-glare déterministe).
bool isGroupRestartInitiator({
  required String me,
  required String peerId,
}) {
  final a = int.tryParse(me);
  final b = int.tryParse(peerId);
  if (a != null && b != null) return a <= b;
  return me.compareTo(peerId) <= 0;
}

/// Caller 1-à-1 seul initie (pas de fallback callee dans ce lot).
bool isOneToOneRestartInitiator({required bool isOutgoingCaller}) =>
    isOutgoingCaller;
