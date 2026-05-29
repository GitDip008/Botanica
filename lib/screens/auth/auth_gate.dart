import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/user_state.dart';
import '../main_nav_screen.dart';
import 'login_screen.dart';

/// Decides which screen to show based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();

    if (userState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1A0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF66BB6A)),
        ),
      );
    }

    if (!userState.isSignedIn) {
      return const LoginScreen();
    }

    return const MainNavScreen();
  }
}
