import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
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
import 'theme/tokens.dart';
import 'i18n/tr.dart';

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

  await initializeDateFormatting(); // fi / sv month and weekday names
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
          // tr() reads the language directly rather than through a provider,
          // so a switch has to rebuild every live widget, not just listeners.
          // ponytail: whole-tree rebuild; fine for a setting changed rarely.
          svc.addListener(() {
            void mark(Element e) {
              e.markNeedsBuild();
              e.visitChildren(mark);
            }
            WidgetsBinding.instance.rootElement?.visitChildren(mark);
          });
          return svc;
        }),
      ],
      // Consumer so Material's own text (tooltips, pickers) follows too.
      child: Consumer<LanguageService>(
        builder: (context, _, _) => MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          title: 'Botanica',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: Locale(trLocale()),
          supportedLocales: const [Locale('en'), Locale('fi'), Locale('sv')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) =>
              OfflineBannerOverlay(child: child ?? const SizedBox.shrink()),
          home: const AuthGate(),
        ),
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
        backgroundColor: C.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: C.danger, size: 40),
                const SizedBox(height: 16),
                const Text(
                  "Botanica couldn't start",
                  style: TextStyle(
                      color: C.textHi,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: C.textSoft, fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
