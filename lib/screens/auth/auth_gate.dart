import 'package:botanica_ar/screens/navigation_screen/navigation_screen.dart';
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
        MapPoint(-135.2031, 8.9552),
        MapPoint(-134.6223, 7.8975),
        MapPoint(-134.9737, 9.3857),
        MapPoint(-135.3179, 10.0360),
        MapPoint(-135.3179, 10.6382),
        MapPoint(-134.8403, 11.1427),
        MapPoint(-134.1530, 11.1427),
        MapPoint(-133.2754, 11.3314),
        MapPoint(-132.6586, 11.7190),
        MapPoint(-131.9554, 12.1610),
        MapPoint(-131.5648, 12.7740),
        MapPoint(-130.8462, 13.3206),
        MapPoint(-130.5426, 13.7822),
        MapPoint(-130.1991, 14.3632),
        MapPoint(-129.8222, 15.0008),
        MapPoint(-128.7644, 15.0008),
        MapPoint(-127.5994, 14.9126),
        MapPoint(-129.1322, 15.0008),
        MapPoint(-130.3548, 15.0008),
        MapPoint(-130.8444, 15.0008),
        MapPoint(-131.3107, 15.0008),
        MapPoint(-131.8921, 15.0008),
        MapPoint(-132.4351, 15.0008),
        MapPoint(-130.4866, 13.7822),
        MapPoint(-134.9295, 11.6840),
        MapPoint(-135.0242, 12.2592),
        MapPoint(-135.0242, 12.8884),
        MapPoint(-135.1896, 13.4985),
        MapPoint(-135.1896, 13.9879),
        MapPoint(-135.4137, 11.1564),
        MapPoint(-136.4625, 10.7244),
        MapPoint(-136.7658, 10.3243),
        MapPoint(-137.5081, 10.2747),
        MapPoint(-138.0620, 10.0672),
        MapPoint(-138.7172, 9.9832),
        MapPoint(-139.3304, 9.9832),
        MapPoint(-140.0859, 9.3577),
        MapPoint(-140.0937, 8.2654),
        MapPoint(-140.0937, 7.2185),
        MapPoint(-140.0937, 6.0266),
        MapPoint(-139.4643, 5.1106),
        MapPoint(-138.4508, 5.1106),
        MapPoint(-137.5812, 5.6391),
        MapPoint(-137.0252, 6.2966),
        MapPoint(-136.1210, 5.6551),
        MapPoint(-135.4414, 5.2939),
        MapPoint(-134.4675, 5.1033),
        MapPoint(-133.6744, 5.1033),
        MapPoint(-133.2025, 5.1033),
        MapPoint(-136.4245, 7.0070),
        MapPoint(-135.6235, 7.6674),
        MapPoint(-133.5866, 7.8975),
        MapPoint(-132.4497, 7.8975),
        MapPoint(-131.2683, 7.8975),
        MapPoint(-130.0969, 7.8975),
        MapPoint(-129.6964, 7.0170),
        MapPoint(-129.4060, 5.9164),
        MapPoint(-130.5474, 5.0959),
        MapPoint(-131.3684, 5.0959),
        MapPoint(-129.6563, 8.8281),
        MapPoint(-128.8454, 9.6185),
        MapPoint(-128.3247, 10.3490),
        MapPoint(-129.2458, 10.7692),
        MapPoint(-130.0885, 11.1536),
        MapPoint(-130.7176, 11.1536),
        MapPoint(-127.5994, 10.5353),
        MapPoint(-128.4649, 5.2973),
        MapPoint(-127.3913, 5.2973),
        MapPoint(-126.2411, 5.2973),
        MapPoint(-125.6452, 6.2188),
        MapPoint(-125.0599, 7.0969),
        MapPoint(-125.0599, 8.1888),
        MapPoint(-125.0599, 8.8959),
        MapPoint(-125.7902, 9.8018),
        MapPoint(-124.7639, 9.8018),
        MapPoint(-124.7639, 11.0139),
        MapPoint(-124.7639, 12.2026),
        MapPoint(-124.7639, 11.7267),
        MapPoint(-126.7667, 9.9759),
        MapPoint(-127.5994, 11.4757),
        MapPoint(-127.5994, 12.3817),
        MapPoint(-127.5994, 13.2158),
        MapPoint(-127.5994, 14.0871),
        MapPoint(-129.5883, 15.0008),
        MapPoint(-131.1365, 15.0008),
        MapPoint(-131.7305, 15.0008),
        MapPoint(-132.5314, 15.0008),
        MapPoint(-127.1004, 15.7241),
        MapPoint(-126.4147, 16.4475),
        MapPoint(-125.5749, 17.2185),
        MapPoint(-124.7915, 16.3401),
        MapPoint(-124.7915, 15.4601),
        MapPoint(-124.7915, 14.4041),
        MapPoint(-124.7915, 13.6219),
        MapPoint(-124.9889, 18.3018),
        MapPoint(-124.9889, 19.4242),
        MapPoint(-125.6042, 20.3806),
        MapPoint(-126.5962, 20.6638),
        MapPoint(-127.6587, 20.6638),
        MapPoint(-128.7504, 20.6638),
        MapPoint(-129.1695, 19.5922),
        MapPoint(-129.4806, 20.6638),
        MapPoint(-129.1900, 18.5399),
        MapPoint(-129.8240, 18.0510),
        MapPoint(-130.3268, 17.5724),
        MapPoint(-130.5887, 20.6638),
        MapPoint(-131.6385, 20.6638),
        MapPoint(-132.8536, 20.6638),
        MapPoint(-133.8675, 20.6638),
        MapPoint(-134.9251, 20.6638),
        MapPoint(-136.0312, 20.6638),
        MapPoint(-136.5435, 19.5584),
        MapPoint(-136.5435, 18.3200),
        MapPoint(-136.5435, 17.2870),
        MapPoint(-136.5435, 16.1084),
        MapPoint(-136.8948, 15.0472),
        MapPoint(-137.7953, 14.3836),
        MapPoint(-138.8259, 14.3836),
        MapPoint(-139.9870, 13.9059),
        MapPoint(-140.3313, 12.9068),
        MapPoint(-140.3313, 11.8499),
        MapPoint(-140.3313, 10.5967),
        MapPoint(-140.8526, 9.3577),
        MapPoint(-141.9412, 9.3577),
        MapPoint(-143.0741, 9.2639),
        MapPoint(-144.2515, 9.2639),
        MapPoint(-145.3524, 9.2639),
        MapPoint(-146.4991, 9.2639),
        MapPoint(-147.7988, 9.2639),
        MapPoint(-149.1443, 9.2639),
        MapPoint(-150.0617, 9.2639),
        MapPoint(-151.2390, 9.2639),
        MapPoint(-152.3552, 10.1349),
        MapPoint(-153.5172, 10.4405),
        MapPoint(-154.8169, 10.4405),
        MapPoint(-155.9636, 10.0891),
        MapPoint(-156.9031, 9.3709),
        MapPoint(-156.9031, 8.2400),
        MapPoint(-156.9031, 5.7726),
        MapPoint(-156.9031, 3.4640),
        MapPoint(-156.9031, 1.4283),
        MapPoint(-157.9182, 1.5991),
        MapPoint(-158.6778, 1.5991),
        MapPoint(-159.8234, 1.5991),
        MapPoint(-159.8234, 0.8400),
        MapPoint(-159.8234, -0.2993),
        MapPoint(-159.8234, -1.4781),
        MapPoint(-160.4360, -2.4118),
        MapPoint(-159.6195, -3.4443),
        MapPoint(-159.4421, -4.0095),
        MapPoint(-158.8241, -3.7426),
        MapPoint(-160.0409, -4.2681),
        MapPoint(-161.5193, -2.4118),
        MapPoint(-162.5922, -2.4118),
        MapPoint(-163.6557, -2.4118),
        MapPoint(-164.8322, -2.4118),
        MapPoint(-165.7864, -3.1078),
        MapPoint(-165.7864, -4.1967),
        MapPoint(-165.7864, -5.2517),
        MapPoint(-164.5958, -5.6774),
        MapPoint(-163.9014, -5.6774),
        MapPoint(-163.2010, -5.6774),
        MapPoint(-162.4534, -5.9714),
        MapPoint(-161.7934, -6.4364),
        MapPoint(-161.2584, -7.3901),
        MapPoint(-160.9934, -7.9133),
        MapPoint(-161.2065, -8.8991),
        MapPoint(-159.9725, -8.7493),
        MapPoint(-165.7451, -6.1544),
        MapPoint(-165.7451, -7.2985),
        MapPoint(-165.7451, -8.3255),
        MapPoint(-165.7451, -9.4806),
        MapPoint(-165.4555, -10.4879),
        MapPoint(-164.6213, -11.1595),
        MapPoint(-163.6133, -11.1595),
        MapPoint(-162.7151, -10.4110),
        MapPoint(-161.9356, -9.6298),
        MapPoint(-161.1512, -10.5748),
        MapPoint(-160.7634, -10.8314),
        MapPoint(-160.3884, -11.3164),
        MapPoint(-160.1585, -12.0061),
        MapPoint(-160.6084, -10.9464),
        MapPoint(-158.8596, -8.7493),
        MapPoint(-157.9130, -9.3514),
        MapPoint(-157.5920, -10.4605),
        MapPoint(-156.7666, -11.1845),
        MapPoint(-155.6935, -11.1845),
        MapPoint(-154.6755, -11.1845),
        MapPoint(-153.7125, -10.7904),
        MapPoint(-153.0807, -9.8647),
        MapPoint(-153.0807, -8.8393),
        MapPoint(-153.2036, -7.7970),
        MapPoint(-153.7755, -6.8140),
        MapPoint(-154.8198, -6.4770),
        MapPoint(-155.7224, -5.8381),
        MapPoint(-155.7224, -4.7228),
        MapPoint(-155.5456, -3.7046),
        MapPoint(-154.9779, -2.8678),
        MapPoint(-155.9545, -2.0948),
        MapPoint(-153.8701, -3.4843),
        MapPoint(-153.1231, -4.0577),
        MapPoint(-152.3373, -4.2876),
        MapPoint(-154.3981, -2.3533),
        MapPoint(-153.5159, -1.5704),
        MapPoint(-152.9914, -0.5457),
        MapPoint(-152.9914, 0.5041),
        MapPoint(-153.6289, 1.2758),
        MapPoint(-154.7872, 1.4283),
        MapPoint(-155.8556, 1.4283),
        MapPoint(-156.9031, 2.3346),
        MapPoint(-156.9031, 4.5478),
        MapPoint(-156.9031, 6.9526),
      ];

      return IndoorMapScreen(
        mapSize: const Size(1050, 500),
        navigationPath: allNodes, // truyền thẳng list
      );
    }
    return const MainNavScreen();
  }
}
