import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/language_service.dart';
import 'services/user_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Real Firebase auth — backed by Firestore /users/{uid} ─────────────────
  AuthService.instance = FirebaseAuthService();

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
        home: const AuthGate(),
      ),
    );
  }
}
