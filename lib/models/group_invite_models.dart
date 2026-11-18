/// Lien et QR code d'invitation de groupe — modèles des réponses serveur.
library;

bool _flag(Object? v) => v == true || v == 1 || v == '1' || v == 'true';
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String? _str(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// `GET /conversations/:id/invite-settings` : réglages et droits, sans lien.
class GroupInviteSettings {
  final bool onlyAdminsCanShareLink;
  final bool approveNewMembers;
  final bool isAdmin;
  final bool canShare;
  final int pendingJoinRequests;

  const GroupInviteSettings({
    required this.onlyAdminsCanShareLink,
    required this.approveNewMembers,
    required this.isAdmin,
    required this.canShare,
    required this.pendingJoinRequests,
  });

  factory GroupInviteSettings.fromJson(Map<String, dynamic> j) => GroupInviteSettings(
        onlyAdminsCanShareLink: _flag(j['onlyAdminsCanShareLink']),
        approveNewMembers: _flag(j['approveNewMembers']),
        isAdmin: _flag(j['isAdmin']),
        canShare: _flag(j['canShare']),
        pendingJoinRequests: _int(j['pendingJoinRequests']),
      );
}

/// `GET /conversations/:id/invite-link` et sa réinitialisation.
class GroupInviteLinkInfo {
  final String token;
  final String url;
  final bool onlyAdminsCanShareLink;
  final bool approveNewMembers;

  const GroupInviteLinkInfo({
    required this.token,
    required this.url,
    required this.onlyAdminsCanShareLink,
    required this.approveNewMembers,
  });

  factory GroupInviteLinkInfo.fromJson(Map<String, dynamic> j) => GroupInviteLinkInfo(
        token: j['token']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
        onlyAdminsCanShareLink: _flag(j['onlyAdminsCanShareLink']),
        approveNewMembers: _flag(j['approveNewMembers']),
      );
}

/// Situation de l'appelant face au groupe d'un lien.
enum GroupInviteState { canJoin, alreadyMember, pending, removed, full, unknown }

GroupInviteState _state(Object? raw) => switch (raw?.toString()) {
      'can_join' => GroupInviteState.canJoin,
      'already_member' || 'joined' => GroupInviteState.alreadyMember,
      'pending' => GroupInviteState.pending,
      'removed' => GroupInviteState.removed,
      'full' => GroupInviteState.full,
      _ => GroupInviteState.unknown,
    };

/// `GET /groups/invite/:token` (et le scan d'un QR de groupe).
class GroupInvitePreview {
  final String token;
  final GroupInviteState state;
  final String name;
  final String? photo;
  final String? description;
  final int memberCount;
  final bool hideHistory;
  final bool approval;

  /// Donné seulement à un membre : de quoi ouvrir la discussion.
  final int? conversationId;

  const GroupInvitePreview({
    required this.token,
    required this.state,
    required this.name,
    this.photo,
    this.description,
    required this.memberCount,
    required this.hideHistory,
    required this.approval,
    this.conversationId,
  });

  factory GroupInvitePreview.fromJson(String token, Map<String, dynamic> j) {
    final g = j['group'] is Map ? Map<String, dynamic>.from(j['group'] as Map) : const <String, dynamic>{};
    final id = _int(g['conversID']);
    return GroupInvitePreview(
      token: token,
      state: _state(j['state']),
      name: g['name']?.toString() ?? '',
      photo: _str(g['photo']),
      description: _str(g['description']),
      memberCount: _int(g['memberCount']),
      hideHistory: _flag(g['hideHistory']),
      approval: _flag(g['approval']),
      conversationId: id > 0 ? id : null,
    );
  }

  GroupInvitePreview copyWith({GroupInviteState? state, int? conversationId}) => GroupInvitePreview(
        token: token,
        state: state ?? this.state,
        name: name,
        photo: photo,
        description: description,
        memberCount: memberCount,
        hideHistory: hideHistory,
        approval: approval,
        conversationId: conversationId ?? this.conversationId,
      );
}

/// `POST /groups/invite/:token/join`.
class GroupJoinResult {
  /// `joined`, `already_member` ou `pending`.
  final String state;
  final int? conversationId;

  const GroupJoinResult({required this.state, this.conversationId});

  bool get isMember => state == 'joined' || state == 'already_member';

  factory GroupJoinResult.fromJson(Map<String, dynamic> j) {
    final conv = j['conversation'];
    final id = conv is Map ? _int(conv['conversID']) : 0;
    return GroupJoinResult(
      state: j['state']?.toString() ?? '',
      conversationId: id > 0 ? id : null,
    );
  }
}

/// Une demande d'adhésion en attente (vue admin).
class GroupJoinRequest {
  final int alanyaID;
  final String nom;
  final String pseudo;
  final String? avatarUrl;
  final DateTime? requestedAt;
  final bool isContact;

  const GroupJoinRequest({
    required this.alanyaID,
    required this.nom,
    required this.pseudo,
    this.avatarUrl,
    this.requestedAt,
    required this.isContact,
  });

  String get displayName {
    final n = nom.trim();
    return n.isNotEmpty ? n : pseudo.trim();
  }

  factory GroupJoinRequest.fromJson(Map<String, dynamic> j) => GroupJoinRequest(
        alanyaID: _int(j['alanyaID']),
        nom: j['nom']?.toString() ?? '',
        pseudo: j['pseudo']?.toString() ?? '',
        avatarUrl: _str(j['avatar_url']),
        requestedAt: DateTime.tryParse(j['requestedAt']?.toString() ?? '')?.toLocal(),
        isContact: _flag(j['isContact']),
      );
}
