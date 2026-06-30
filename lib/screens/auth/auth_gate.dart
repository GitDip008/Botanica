import 'package:botanica_ar/screens/navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/user_state.dart';
import '../../services/version_check_service.dart';
import '../main_nav_screen.dart';
import '../update_required_screen.dart';
import 'login_screen.dart';

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
        backgroundColor: Color(0xFF0A1A0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF66BB6A)),
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
        backgroundColor: Color(0xFF0A1A0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF66BB6A)),
        ),
      );
    }
    if (!userState.isSignedIn) {
      final List<MapPoint> allNodes = [
        MapPoint(-161.16, -10.59), // Node 1
        MapPoint(-160.84, -10.83), // Node 2
        MapPoint(-160.42, -11.18), // Node 3
        MapPoint(-160.04, -11.50), // Node 4
        MapPoint(-160.02, -12.00), // Node 5
        MapPoint(-160.28, -11.87), // Node 6
        MapPoint(-153.88, -3.44), // Node 7
        MapPoint(-152.35, -4.27), // Node 8
        MapPoint(-153.41, -3.77), // Node 9
        MapPoint(-161.26, -7.74), // Node 10
        MapPoint(-161.45, -7.11), // Node 11
        MapPoint(-161.78, -6.56), // Node 12
        MapPoint(-162.93, -5.82), // Node 13
        MapPoint(-165.59, -5.70), // Node 14
        MapPoint(-164.35, -5.70), // Node 15
        MapPoint(-159.68, -3.45), // Node 16
        MapPoint(-160.07, -4.30), // Node 17
        MapPoint(-159.48, -4.03), // Node 18
        MapPoint(-156.85, 8.55), // Node 19
        MapPoint(-156.85, 7.51), // Node 20
        MapPoint(-156.85, 6.55), // Node 21
        MapPoint(-156.85, 5.41), // Node 22
        MapPoint(-156.85, 4.37), // Node 23
        MapPoint(-156.85, 3.32), // Node 24
        MapPoint(-156.84, 2.46), // Node 25
        MapPoint(-155.82, 1.41), // Node 26
        MapPoint(-154.77, 1.41), // Node 27
        MapPoint(-153.68, 1.41), // Node 28
        MapPoint(-152.98, 0.71), // Node 29
        MapPoint(-152.98, -0.61), // Node 30
        MapPoint(-153.45, -1.55), // Node 31
        MapPoint(-154.27, -2.27), // Node 32
        MapPoint(-155.05, -3.14), // Node 33
        MapPoint(-155.55, -4.01), // Node 34
        MapPoint(-155.55, -4.74), // Node 35
        MapPoint(-155.55, -5.74), // Node 36
        MapPoint(-155.55, -6.54), // Node 37
        MapPoint(-154.46, -6.54), // Node 38
        MapPoint(-153.55, -6.93), // Node 39
        MapPoint(-153.14, -7.89), // Node 40
        MapPoint(-153.00, -8.92), // Node 41
        MapPoint(-153.17, -10.08), // Node 42
        MapPoint(-153.85, -10.97), // Node 43
        MapPoint(-155.00, -11.32), // Node 44
        MapPoint(-156.11, -11.32), // Node 45
        MapPoint(-157.06, -10.81), // Node 46
        MapPoint(-157.71, -9.87), // Node 47
        MapPoint(-158.16, -8.82), // Node 48
        MapPoint(-159.44, -8.82), // Node 49
        MapPoint(-160.60, -8.82), // Node 50
        MapPoint(-161.58, -9.28), // Node 51
        MapPoint(-162.25, -9.90), // Node 52
        MapPoint(-162.83, -10.43), // Node 53
        MapPoint(-163.70, -11.21), // Node 54
        MapPoint(-164.89, -11.21), // Node 55
        MapPoint(-165.59, -10.32), // Node 56
        MapPoint(-165.59, -9.24), // Node 57
        MapPoint(-165.59, -8.19), // Node 58
        MapPoint(-165.59, -7.11), // Node 59
        MapPoint(-165.59, -5.87), // Node 60
        MapPoint(-165.59, -4.84), // Node 61
        MapPoint(-165.59, -3.55), // Node 62
        MapPoint(-165.59, -2.41), // Node 63
        MapPoint(-164.40, -2.41), // Node 64
        MapPoint(-163.24, -2.41), // Node 65
        MapPoint(-162.01, -2.41), // Node 66
        MapPoint(-160.84, -2.41), // Node 67
        MapPoint(-159.84, -1.93), // Node 68
        MapPoint(-159.84, -0.81), // Node 69
        MapPoint(-159.84, 0.29), // Node 70
        MapPoint(-159.84, 1.53), // Node 71
        MapPoint(-156.83, 1.41), // Node 72
        MapPoint(-158.25, 1.53), // Node 73
      ];

      return IndoorMapScreen(
        mapSize: const Size(1050, 500),
        navigationPath: allNodes, // truyền thẳng list
      );
    }
    return const MainNavScreen();
  }
}
