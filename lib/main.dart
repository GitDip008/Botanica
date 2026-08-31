import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/user_state.dart';
import 'widgets/offline_banner.dart';

void main() async {
  // A failure during startup used to leave the splash on screen forever — a
  // blank page with no way to tell what went wrong, which is the worst possible
  // outcome for a visitor standing in the garden. Anything unhandled here now
  // renders the reason instead.
  runZonedGuarded(_start, (e, s) {
    debugPrint('STARTUP FAILURE: $e\n$s');
    runApp(_StartupError(error: '$e'));
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── App Check — proves calls come from the genuine app, not a script.
  // Play Integrity in release; debug provider in dev so the emulator/`flutter
  // run` keeps working (register the printed debug token in the console once).
  //
  // Skipped on web: the browser needs a reCAPTCHA site key, and activating
  // without one throws before runApp — a white screen instead of an app. App
  // Check is unenforced on the callables anyway (see CLAUDE.md), so the web
  // build loses nothing today. Add a webProvider when it is re-enforced.
  if (!kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      );
    } catch (e) {
      debugPrint('App Check unavailable: $e');
    }
  }

  // ── Real Firebase auth — backed by Firestore /users/{uid} ───────────
  AuthService.instance = FirebaseAuthService();

  // Optional services. Wrapped because NONE of them are worth a blank screen:
  // push needs a service worker the browser may not have, connectivity probes
  // the network. A visitor standing in the garden should get the app either
  // way, and find out later that notifications are off.
  try {
    NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }
  try {
    ConnectivityService.instance.init();
  } catch (e) {
    debugPrint('Connectivity monitoring unavailable: $e');
  }

  runApp(const BotanicaApp());
}

class BotanicaApp extends StatelessWidget {
  const BotanicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserState()),
        ChangeNotifierProvider(create: (_) {
          final svc = LanguageService();
          LanguageService.register(svc);
          return svc;
        }),
      ],
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'Botanica',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2E7D32),
            secondary: Color(0xFF66BB6A),
            surface: Color(0xFF1A2E1E),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFFE8F5E9),
          ),
          scaffoldBackgroundColor: const Color(0xFF0A1A0F),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D1F14),
            foregroundColor: Color(0xFFE8F5E9),
            elevation: 0,
          ),
        ),
        builder: (context, child) =>
            OfflineBannerOverlay(child: child ?? const SizedBox.shrink()),
        home: const AuthGate(),
      ),
    );
  }
}

/// Shown when startup throws. Better a readable reason on screen than a splash
/// that never goes away.
class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1A0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFEF5350), size: 40),
                const SizedBox(height: 16),
                const Text(
                  "Botanica couldn't start",
                  style: TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF9CCC9F), fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
