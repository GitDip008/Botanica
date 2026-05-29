import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Production auth service backed by Firebase Auth + Firestore.
/// Firestore stores extended user data (tier, usage, isAdmin) under /users/{uid}.
class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  StreamSubscription<fb.User?>? _authSub;

  FirebaseAuthService() {
    _authSub = _auth.authStateChanges().listen(_handleAuthChange);
  }

  Future<void> _handleAuthChange(fb.User? fbUser) async {
    if (fbUser == null) {
      _currentUser = null;
      _controller.add(null);
      return;
    }
    _currentUser = await _loadOrCreateUserDoc(fbUser);
    _controller.add(_currentUser);
  }

  /// Loads the user's Firestore document; creates one on first sign-in.
  Future<AppUser> _loadOrCreateUserDoc(fb.User fbUser) async {
    final docRef = _firestore.collection('users').doc(fbUser.uid);
    final snap = await docRef.get();

    if (snap.exists) {
      var user = AppUser.fromJson(snap.data()!);
      // Auto-promote: if this email is now in the admin list but Firestore
      // hasn't been updated yet, fix it on the fly.
      final shouldBeAdmin =
          AppUser.adminEmails.contains(user.email.toLowerCase());
      if (shouldBeAdmin && (!user.isAdmin || !user.tier.isPremium)) {
        user = user.copyWith(
          isAdmin: true,
          tier: SubscriptionTier.premium,
        );
        await docRef.update({
          'isAdmin': true,
          'tier': SubscriptionTier.premium.name,
        });
      }
      return user;
    }

    // First-time sign-in — create a new user document.
    final email = fbUser.email ?? '';
    final newUser = AppUser(
      id: fbUser.uid,
      email: email,
      displayName: fbUser.displayName ?? email.split('@').first,
      photoUrl: fbUser.photoURL,
      tier: AppUser.adminEmails.contains(email.toLowerCase())
          ? SubscriptionTier.premium
          : SubscriptionTier.free,
      joinedAt: DateTime.now(),
      isAdmin: AppUser.adminEmails.contains(email.toLowerCase()),
    );
    await docRef.set(newUser.toJson());
    return newUser;
  }

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = await _loadOrCreateUserDoc(cred.user!);
      _controller.add(_currentUser);
      return _currentUser!;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user!.updateDisplayName(displayName);
      final newUser = AppUser(
        id: cred.user!.uid,
        email: email,
        displayName: displayName,
        tier: SubscriptionTier.free,
        joinedAt: DateTime.now(),
        isAdmin: AppUser.adminEmails.contains(email.toLowerCase()),
      );
      await _firestore.collection('users').doc(cred.user!.uid).set(newUser.toJson());
      _currentUser = newUser;
      _controller.add(_currentUser);
      return newUser;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final cred = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final fbCred = await _auth.signInWithCredential(cred);
    _currentUser = await _loadOrCreateUserDoc(fbCred.user!);
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  @override
  Future<AppUser> updateProfile({String? displayName, String? photoUrl}) async {
    if (_currentUser == null) throw Exception('Not signed in');
    final updated = _currentUser!.copyWith(
      displayName: displayName,
      photoUrl: photoUrl,
    );
    await _firestore.collection('users').doc(updated.id).update(updated.toJson());
    _currentUser = updated;
    _controller.add(updated);
    return updated;
  }

  @override
  Future<AppUser> updateTier(SubscriptionTier tier) async {
    if (_currentUser == null) throw Exception('Not signed in');
    final updated = _currentUser!.copyWith(tier: tier);
    await _firestore.collection('users').doc(updated.id).update({'tier': tier.name});
    _currentUser = updated;
    _controller.add(updated);
    return updated;
  }

  @override
  Future<AppUser> incrementChatUsage(String chatId) async {
    if (_currentUser == null) throw Exception('Not signed in');
    final reset = _shouldResetDaily(_currentUser!.lastUsageReset);
    final base = reset ? <String>[] : List<String>.from(_currentUser!.chatsUsedTodayIds);
    if (!base.contains(chatId)) base.add(chatId);
    final updated = _currentUser!.copyWith(
      chatsUsedTodayIds: base,
      lastUsageReset: reset ? DateTime.now() : _currentUser!.lastUsageReset,
    );
    await _firestore.collection('users').doc(updated.id).update({
      'chatsUsedTodayIds': updated.chatsUsedTodayIds,
      'lastUsageReset': updated.lastUsageReset?.toIso8601String(),
    });
    _currentUser = updated;
    _controller.add(updated);
    return updated;
  }

  @override
  Future<AppUser> incrementHuntUsage() async {
    if (_currentUser == null) throw Exception('Not signed in');
    final reset = _shouldResetDaily(_currentUser!.lastUsageReset);
    final updated = _currentUser!.copyWith(
      huntsCompletedToday: reset ? 1 : _currentUser!.huntsCompletedToday + 1,
      lastUsageReset: reset ? DateTime.now() : _currentUser!.lastUsageReset,
    );
    await _firestore.collection('users').doc(updated.id).update({
      'huntsCompletedToday': updated.huntsCompletedToday,
      'lastUsageReset': updated.lastUsageReset?.toIso8601String(),
    });
    _currentUser = updated;
    _controller.add(updated);
    return updated;
  }

  bool _shouldResetDaily(DateTime? last) {
    if (last == null) return true;
    final now = DateTime.now();
    return last.year != now.year || last.month != now.month || last.day != now.day;
  }

  String _friendlyAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found for that email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong password';
      case 'email-already-in-use':
        return 'An account already exists for that email';
      case 'weak-password':
        return 'Password is too weak (use 6+ characters)';
      case 'network-request-failed':
        return 'No internet connection';
      default:
        return e.message ?? 'Authentication error';
    }
  }

  void dispose() {
    _authSub?.cancel();
    _controller.close();
  }
}
