import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/user_state.dart';
import '../../services/version_check_service.dart';
import '../main_nav_screen.dart';
import '../update_required_screen.dart';
import 'login_screen.dart';
import '../../theme/tokens.dart';

/// Decides which screen to show based on auth state + version check.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _updateRequired = false;
  String _latestVersion = '';
  String _downloadUrl = '';

  @override
  void initState() {
    super.initState();
    _runVersionCheck();
  }

  Future<void> _runVersionCheck() async {
    final result = await VersionCheckService.instance.check();
    if (mounted) {
      setState(() {
        _updateRequired = result.required;
        _latestVersion = result.latest;
        _downloadUrl = result.downloadUrl;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: CircularProgressIndicator(color: C.accent),
        ),
      );
    }

    if (_updateRequired) {
      return UpdateRequiredScreen(
        latestVersion: _latestVersion,
        downloadUrl: _downloadUrl,
      );
    }

    final userState = context.watch<UserState>();
    if (userState.isLoading) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: CircularProgressIndicator(color: C.accent),
        ),
      );
    }
    if (!userState.isSignedIn) {
      return const LoginScreen();
    }
    return const MainNavScreen();
  }
}
