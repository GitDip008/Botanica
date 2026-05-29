import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Abstract auth service. Swap implementations (Mock <-> Firebase) by changing
/// the instance assigned to [AuthService.instance].
abstract class AuthService {
  static late AuthService instance;

  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;

  Future<AppUser> signInWithEmail({required String email, required String password});
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });
  Future<AppUser> signInWithGoogle();
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);

  Future<AppUser> updateProfile({String? displayName, String? photoUrl});
  Future<AppUser> updateTier(SubscriptionTier tier);

  /// Marks `chatId` as used today. Idempotent — same chat twice in one day
  /// counts once. Resets at midnight.
  Future<AppUser> incrementChatUsage(String chatId);
  Future<AppUser> incrementHuntUsage();
}

// ─── Mock implementation — works fully offline for development/testing ───────
class MockAuthService implements AuthService {
  static const _prefsKey = 'mock_auth_user';
  AppUser? _currentUser;
  final _controller = StreamController<AppUser?>.broadcast();

  MockAuthService() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      _currentUser = AppUser.fromJson(jsonDecode(raw));
      _controller.add(_currentUser);
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(_currentUser!.toJson()));
    }
  }

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (password.length < 6) {
      throw Exception('Password too short (mock)');
    }
    _currentUser = AppUser(
      id: 'mock-${email.hashCode.abs()}',
      email: email,
      displayName: email.split('@').first,
      tier: SubscriptionTier.free,
      joinedAt: DateTime.now(),
    );
    await _saveToPrefs();
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    if (!email.contains('@')) {
      throw Exception('Invalid email');
    }
    _currentUser = AppUser(
      id: 'mock-${email.hashCode.abs()}',
      email: email,
      displayName: displayName,
      tier: SubscriptionTier.free,
      joinedAt: DateTime.now(),
    );
    await _saveToPrefs();
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 700));
    _currentUser = AppUser(
      id: 'mock-google-user',
      email: 'visitor@gmail.com',
      displayName: 'Garden Visitor',
      tier: SubscriptionTier.free,
      joinedAt: DateTime.now(),
    );
    await _saveToPrefs();
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _saveToPrefs();
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // No-op in mock — just pretends to send.
  }

  @override
  Future<AppUser> updateProfile({String? displayName, String? photoUrl}) async {
    if (_currentUser == null) throw Exception('Not signed in');
    _currentUser = _currentUser!.copyWith(
      displayName: displayName,
      photoUrl: photoUrl,
    );
    await _saveToPrefs();
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> updateTier(SubscriptionTier tier) async {
    if (_currentUser == null) throw Exception('Not signed in');
    _currentUser = _currentUser!.copyWith(tier: tier);
    await _saveToPrefs();
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> incrementChatUsage(String chatId) async {
    if (_currentUser == null) throw Exception('Not signed in');
    final reset = _shouldResetDaily(_currentUser!.lastUsageReset);
    final base = reset ? <String>[] : List<String>.from(_currentUser!.chatsUsedTodayIds);
    if (!base.contains(chatId)) base.add(chatId);
    _currentUser = _currentUser!.copyWith(
      chatsUsedTodayIds: base,
      lastUsageReset: reset ? DateTime.now() : _currentUser!.lastUsageReset,
    );
    await _saveToPrefs();
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> incrementHuntUsage() async {
    if (_currentUser == null) throw Exception('Not signed in');
    final reset = _shouldResetDaily(_currentUser!.lastUsageReset);
    _currentUser = _currentUser!.copyWith(
      huntsCompletedToday: reset ? 1 : _currentUser!.huntsCompletedToday + 1,
      lastUsageReset: reset ? DateTime.now() : _currentUser!.lastUsageReset,
    );
    await _saveToPrefs();
    _controller.add(_currentUser);
    return _currentUser!;
  }

  bool _shouldResetDaily(DateTime? last) {
    if (last == null) return true;
    final now = DateTime.now();
    return last.year != now.year || last.month != now.month || last.day != now.day;
  }
}
