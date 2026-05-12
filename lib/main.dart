import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:safe_text/safe_text.dart';
import 'package:tcgp_trading_app/auth/auth_gate.dart';
import 'package:tcgp_trading_app/config/app_colors.dart';
import 'package:tcgp_trading_app/firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  _validateRequiredEnv();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_API_KEY'] ?? '');

  await SafeTextFilter.init(language: Language.english);

  runApp(const MyApp());
}

void _validateRequiredEnv() {
  const requiredKeys = [
    'SUPABASE_URL',
    'SUPABASE_API_KEY',
    'GOOGLE_WEB_CLIENT_ID',
  ];
  final missing = requiredKeys
      .where((key) => (dotenv.env[key] ?? '').trim().isEmpty)
      .toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'Missing required environment values: ${missing.join(', ')}. '
      'Create a local .env from .env.example before running the app.',
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PocketTrading',
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0F),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 48,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 48,
          backgroundColor: const Color(0xFF141418),
          surfaceTintColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary);
            }
            return const IconThemeData(color: Colors.white54);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1E1E24),
          contentTextStyle: TextStyle(color: Colors.white70),
        ),
      ),
      home: AuthGate(),
    );
  }
}
