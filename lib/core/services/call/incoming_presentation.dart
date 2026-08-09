/// Propriétaire de la présentation UI d'un appel entrant (≠ [CallStatus.incoming]).
enum IncomingPresentationOwner {
  none,
  flutterScreen,
  nativeCallKit,
}

/// Action recommandée pour un signal / handoff entrant.
enum IncomingPresentationAction {
  showFlutterIncoming,
  showNativeCallKit,
  mergeOnly,
  handoffToFlutter,
  handoffToNative,
  ignore,
}

/// Intention du chemin d'entrée (signaling, CallKit, lifecycle).
enum IncomingPresentationIntent {
  signal,
  prepareFromCallKit,
  handoffToNative,
  handoffToFlutter,
}

/// État ownership lié à un [callId] (jamais un flag global sans id).
class IncomingPresentationState {
  final IncomingPresentationOwner owner;
  final String? callId;

  const IncomingPresentationState({
    this.owner = IncomingPresentationOwner.none,
    this.callId,
  });

  bool get isActive =>
      owner != IncomingPresentationOwner.none &&
      callId != null &&
      callId!.isNotEmpty;

  static const IncomingPresentationState empty = IncomingPresentationState();
}

class IncomingPresentationClaimResult {
  final IncomingPresentationState state;
  final bool changed;
  final bool ignored;

  const IncomingPresentationClaimResult({
    required this.state,
    required this.changed,
    required this.ignored,
  });
}

/// Décision pure : quelle UI / transition pour un entrant.
IncomingPresentationAction decideIncomingPresentation({
  required String callId,
  required bool appForeground,
  required IncomingPresentationOwner currentOwner,
  required String? currentOwnerCallId,
  required bool isAutoAnsweringFromPush,
  required bool isTerminal,
  required IncomingPresentationIntent intent,
  bool isCallKitActive = false,
}) {
  final id = callId.trim();
  if (id.isEmpty || isTerminal) {
    return IncomingPresentationAction.ignore;
  }

  if (isAutoAnsweringFromPush) {
    return IncomingPresentationAction.mergeOnly;
  }

  if (intent == IncomingPresentationIntent.handoffToNative) {
    if (currentOwnerCallId != null &&
        currentOwnerCallId.isNotEmpty &&
        currentOwnerCallId != id) {
      return IncomingPresentationAction.ignore;
    }
    return IncomingPresentationAction.handoffToNative;
  }

  if (intent == IncomingPresentationIntent.handoffToFlutter) {
    if (currentOwnerCallId != null &&
        currentOwnerCallId.isNotEmpty &&
        currentOwnerCallId != id) {
      return IncomingPresentationAction.ignore;
    }
    return IncomingPresentationAction.handoffToFlutter;
  }

  // Autre callId déjà propriétaire d'un entrant → politique un à la fois.
  if (currentOwner != IncomingPresentationOwner.none &&
      currentOwnerCallId != null &&
      currentOwnerCallId.isNotEmpty &&
      currentOwnerCallId != id) {
    return IncomingPresentationAction.ignore;
  }

  // Même callId déjà présenté → merge signaling uniquement.
  if (currentOwnerCallId == id &&
      currentOwner != IncomingPresentationOwner.none) {
    return IncomingPresentationAction.mergeOnly;
  }

  if (intent == IncomingPresentationIntent.prepareFromCallKit) {
    if (appForeground) {
      return IncomingPresentationAction.showFlutterIncoming;
    }
    return isCallKitActive
        ? IncomingPresentationAction.mergeOnly
        : IncomingPresentationAction.showNativeCallKit;
  }

  // Signal socket / FCM.
  if (!appForeground) {
    return isCallKitActive
        ? IncomingPresentationAction.mergeOnly
        : IncomingPresentationAction.showNativeCallKit;
  }
  return IncomingPresentationAction.showFlutterIncoming;
}

/// Claim ownership strictement lié au [callId].
IncomingPresentationClaimResult claimIncomingPresentation({
  required IncomingPresentationState current,
  required String callId,
  required IncomingPresentationOwner owner,
  required bool explicitHandoff,
  required bool isTerminal,
}) {
  final id = callId.trim();
  if (id.isEmpty ||
      isTerminal ||
      owner == IncomingPresentationOwner.none) {
    return IncomingPresentationClaimResult(
      state: current,
      changed: false,
      ignored: true,
    );
  }

  // Autre callId pendant un entrant actif → ignorer.
  if (current.isActive && current.callId != id) {
    return IncomingPresentationClaimResult(
      state: current,
      changed: false,
      ignored: true,
    );
  }

  // Même callId + même owner → no-op idempotent.
  if (current.callId == id && current.owner == owner) {
    return IncomingPresentationClaimResult(
      state: current,
      changed: false,
      ignored: false,
    );
  }

  // Transition owner différente sans handoff explicite → ignorer.
  if (current.isActive &&
      current.callId == id &&
      current.owner != owner &&
      !explicitHandoff) {
    return IncomingPresentationClaimResult(
      state: current,
      changed: false,
      ignored: true,
    );
  }

  return IncomingPresentationClaimResult(
    state: IncomingPresentationState(owner: owner, callId: id),
    changed: true,
    ignored: false,
  );
}

/// Clear ciblé : sans [callId] → reset total ; avec [callId] → seulement si match.
IncomingPresentationState clearIncomingPresentationState({
  required IncomingPresentationState current,
  String? callId,
}) {
  if (callId != null) {
    final id = callId.trim();
    if (id.isEmpty || current.callId != id) return current;
  }
  return IncomingPresentationState.empty;
}

/// Politique HomeScreen : ouvrir IncomingCallScreen uniquement si Flutter est owner.
bool evaluateShouldShowFlutterIncomingUi({
  required bool statusIsIncoming,
  required bool isAutoAnsweringFromPush,
  required bool appForeground,
  required IncomingPresentationOwner owner,
  required String? ownerCallId,
  required String? currentCallId,
}) {
  if (!statusIsIncoming || isAutoAnsweringFromPush || !appForeground) {
    return false;
  }
  if (owner != IncomingPresentationOwner.flutterScreen) return false;
  final owned = ownerCallId?.trim() ?? '';
  final active = currentCallId?.trim() ?? '';
  return owned.isNotEmpty && owned == active;
}
