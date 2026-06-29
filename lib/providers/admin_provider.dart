import 'package:flutter/foundation.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';

class AdminStats {
  final int totalUsers;
  final int onlineUsers;
  final int bannedUsers;
  final int messagesPeriod;
  final int callsPeriod;
  final int statusesPeriod;

  const AdminStats({
    this.totalUsers = 0,
    this.onlineUsers = 0,
    this.bannedUsers = 0,
    this.messagesPeriod = 0,
    this.callsPeriod = 0,
    this.statusesPeriod = 0,
  });

  factory AdminStats.fromCounters(Map<String, dynamic> json) => AdminStats(
    totalUsers: _i(json['totalUsers']),
    onlineUsers: _i(json['onlineUsers']),
    bannedUsers: _i(json['bannedUsers']),
    messagesPeriod: _i(json['messagesPeriod']),
    callsPeriod: _i(json['callsPeriod']),
    statusesPeriod: _i(json['statusesPeriod']),
  );

  static int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
}

class AdminProvider extends ChangeNotifier {
  final TalkyApiClient _api;

  List<User> _users = [];
  int _totalUsers = 0;
  int _page = 1;
  int _limit = 20;
  bool _isLoadingUsers = false;
  String _searchQuery = '';

  AdminStats _stats = const AdminStats();
  bool _isLoadingStats = false;
  String? _error;

  AdminProvider({required TalkyApiClient api}) : _api = api;

  List<User> get users => _users;
  int get totalUsers => _totalUsers;
  int get page => _page;
  int get limit => _limit;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingStats => _isLoadingStats;
  AdminStats get stats => _stats;
  String get searchQuery => _searchQuery;
  String? get error => _error;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadUsers({
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    _isLoadingUsers = true;
    _error = null;
    _page = page;
    _limit = limit;
    notifyListeners();
    try {
      final res = await _api.adminGetUsers(
        search: search ?? _searchQuery,
        status: status,
        page: page,
        limit: limit,
      );
      final items = (res['items'] as List? ?? []);
      _users = items
          .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _totalUsers = (res['total'] as num?)?.toInt() ?? _users.length;
    } catch (e) {
      _error = 'Erreur chargement utilisateurs: $e';
      debugPrint('[AdminProvider] loadUsers error: $e');
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    _isLoadingStats = true;
    notifyListeners();
    try {
      final raw = await _api.adminGetStats();
      final counters = Map<String, dynamic>.from(raw['counters'] ?? {});
      _stats = AdminStats.fromCounters(counters);
    } catch (e) {
      debugPrint('[AdminProvider] loadStats error: $e');
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  Future<void> toggleBan(User user, {String? reason}) async {
    try {
      if (user.exclus) {
        await _api.adminUnbanUser(user.alanyaID);
      } else {
        await _api.adminBanUser(user.alanyaID, reason: reason);
      }
      await loadUsers(search: _searchQuery, page: _page, limit: _limit);
    } catch (e) {
      _error = 'Erreur ban/unban: $e';
      notifyListeners();
    }
  }

  Future<void> setAccountType(int userId, int typeCompte) async {
    try {
      await _api.adminSetAccountType(userId, typeCompte: typeCompte);
      await loadUsers(search: _searchQuery, page: _page, limit: _limit);
    } catch (e) {
      _error = 'Erreur changement de rôle: $e';
      notifyListeners();
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _api.adminDeleteUser(userId);
      _users.removeWhere((u) => u.alanyaID == userId);
      _totalUsers = (_totalUsers - 1).clamp(0, 1 << 30);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur suppression: $e';
      notifyListeners();
    }
  }

  void updatePresence(int userId, bool online) {
    final idx = _users.indexWhere((u) => u.alanyaID == userId);
    if (idx == -1) return;
    final u = _users[idx];
    _users[idx] = User(
      alanyaID: u.alanyaID,
      nom: u.nom,
      pseudo: u.pseudo,
      alanyaPhone: u.alanyaPhone,
      email: u.email,
      idPays: u.idPays,
      avatarUrl: u.avatarUrl,
      typeCompte: u.typeCompte,
      isOnline: online,
      lastSeen: u.lastSeen,
      exclus: u.exclus,
      excludeAt: u.excludeAt,
      excludeReason: u.excludeReason,
      createdAt: u.createdAt,
      paysLibelle: u.paysLibelle,
    );
    notifyListeners();
  }

  Future<User> getUserById(int userId) async {
    final data = await _api.adminGetUserById(userId);
    return User.fromJson(Map<String, dynamic>.from(data));
  }

  Future<User> createUser(Map<String, dynamic> body) async {
    final data = await _api.adminCreateUser(body);
    await loadUsers(search: _searchQuery, page: _page, limit: _limit);
    return User.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateUserPhone(int userId, String alanyaPhone) async {
    await _api.adminUpdateUserPhone(userId, alanyaPhone);
  }

  Future<List<Map<String, dynamic>>> loadReservedPhones() async {
    final list = await _api.adminGetReservedPhones();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addReservedPhone(String phone, String label) async {
    await _api.adminAddReservedPhone(phone, label);
  }

  Future<void> removeReservedPhone(String phone) async {
    await _api.adminRemoveReservedPhone(phone);
  }

  static bool isAdmin(User? user) => (user?.typeCompte ?? 0) >= 1;
  static bool isSuperAdmin(User? user) => (user?.typeCompte ?? 0) >= 2;
}
