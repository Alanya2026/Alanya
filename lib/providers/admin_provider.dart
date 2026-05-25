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

  AdminStats({
    this.totalUsers = 0,
    this.onlineUsers = 0,
    this.bannedUsers = 0,
    this.messagesPeriod = 0,
    this.callsPeriod = 0,
    this.statusesPeriod = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['totalUsers'] as int? ?? 0,
      onlineUsers: json['onlineUsers'] as int? ?? 0,
      bannedUsers: json['bannedUsers'] as int? ?? 0,
      messagesPeriod: json['messages_7d'] as int? ?? 0,
      callsPeriod: json['calls_7d'] as int? ?? 0,
      statusesPeriod: json['statuses_7d'] as int? ?? 0,
    );
  }
}

class AdminProvider extends ChangeNotifier {
  final TalkyApiClient api;

  AdminProvider({required this.api});

  AdminStats _stats = AdminStats();
  List<User> _users = [];
  int _page = 1;
  int _limit = 20;
  int _totalUsers = 0;
  bool _isLoadingStats = false;
  bool _isLoadingUsers = false;
  String _searchQuery = '';

  AdminStats get stats => _stats;
  List<User> get users => _users;
  int get currentPage => _page;
  int get pageCount => (_totalUsers / _limit).ceil();
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get canNextPage => _page < pageCount;
  bool get canPreviousPage => _page > 1;

  Future<void> loadStats() async {
    try {
      _isLoadingStats = true;
      notifyListeners();

      final data = await api.adminGetStats();
      _stats = AdminStats.fromJson(data);

      _isLoadingStats = false;
      notifyListeners();
    } catch (e) {
      _isLoadingStats = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadUsers({String? search, int? page, int? limit}) async {
    try {
      _isLoadingUsers = true;
      notifyListeners();

      final res = await api.adminGetUsers(
        search: search,
        page: page ?? _page,
        limit: limit ?? _limit,
      );

      _users = (res['items'] as List)
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
      _totalUsers = res['total'] as int? ?? 0;

      _isLoadingUsers = false;
      notifyListeners();
    } catch (e) {
      _isLoadingUsers = false;
      notifyListeners();
      rethrow;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  Future<void> toggleBan(int userId, {required bool ban}) async {
    try {
      if (ban) {
        await api.adminBanUser(userId);
      } else {
        await api.adminUnbanUser(userId);
      }
      await loadUsers();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> makeAdmin(int userId) async {
    try {
      await api.adminSetAccountType(userId, typeCompte: 1);
      await loadUsers();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await api.adminDeleteUser(userId);
      await loadUsers();
    } catch (e) {
      rethrow;
    }
  }

  void nextPage() {
    if (canNextPage) {
      _page++;
    }
  }

  void previousPage() {
    if (canPreviousPage) {
      _page--;
    }
  }

  void goToPage(int page) {
    if (page > 0 && page <= pageCount) {
      _page = page;
    }
  }
}
