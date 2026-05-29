import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'chat_service.dart';

/// App-wide reactive user state. Listen with Consumer<UserState> or context.watch.
class UserState extends ChangeNotifier {
  AppUser? _user;
  bool _loading = true;
  StreamSubscription<AppUser?>? _sub;

  UserState() {
    _sub = AuthService.instance.authStateChanges().listen((u) {
      _user = u;
      _loading = false;
      ChatService.instance.setUser(u);
      notifyListeners();
    });
    // Pull current immediately
    _user = AuthService.instance.currentUser;
    ChatService.instance.setUser(_user);
    _loading = false;
  }

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isPremium => _user?.tier.isPremium ?? false;
  bool get isLoading => _loading;

  Future<void> signOut() async {
    await AuthService.instance.signOut();
  }

  Future<void> refresh() async {
    _user = AuthService.instance.currentUser;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
