import 'conversation_summary_reducer.dart';

/// Façade mince historique : délègue à [ConversationSummaryReducer].
class ConversationSummary {
  ConversationSummary(this._reducer);

  final ConversationSummaryReducer _reducer;

  Future<void> bump({
    required int conversID,
    required String preview,
    required int type,
    required DateTime at,
    required int activeConversationID,
    bool fromOther = false,
    int? senderID,
    int? status,
    required int myId,
  }) {
    return _reducer.recompute(conversID, myId);
  }
}
