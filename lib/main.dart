import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
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
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── App Check — proves calls come from the genuine app, not a script.
  // Play Integrity in release; debug provider in dev so the emulator/`flutter
  // run` keeps working (register the printed debug token in the console once).
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
  );

  // ── Real Firebase auth — backed by Firestore /users/{uid} ───────────
  AuthService.instance = FirebaseAuthService();

  // Push notifications — runs in background, doesn't block app start
  NotificationService.instance.init();
  ConnectivityService.instance.init();

  // ProviderScope hosts the vendored navigation module's riverpod state.
  // It sits above the provider-based app and does not affect existing code.
  runApp(const ProviderScope(child: BotanicaApp()));
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
