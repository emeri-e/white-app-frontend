import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/home/screens/home_screen.dart';
import 'package:whiteapp/features/home/screens/welcome.dart';
import 'package:whiteapp/features/auth/screens/login_screen.dart';
import 'package:whiteapp/features/auth/screens/signup_screen.dart';
import 'package:whiteapp/features/home/screens/onboarding_screen.dart';
import 'package:whiteapp/features/recovery/screens/program_list_screen.dart';
import 'package:whiteapp/features/recovery/screens/challenge_list_screen.dart';
import 'package:whiteapp/features/recovery/screens/progress_dashboard_screen.dart';
import 'package:whiteapp/features/onboarding/screens/walkthrough_screen.dart';

import 'package:provider/provider.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/core/services/community_service.dart';
import 'package:whiteapp/core/services/token_storage.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CommunityController(
            communityService: CommunityService(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Match StarryBackground
        primaryColor: const Color(0xFF6366F1), // Indigo
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ).copyWith(
          headlineMedium: GoogleFonts.outfit(
            fontSize: 40, // Increased from 32
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: GoogleFonts.outfit(
            fontSize: 20, // Increased from 18
            color: Colors.white70,
          ),
          labelLarge: GoogleFonts.outfit(
            fontSize: 20, // Increased from 18
            fontWeight: FontWeight.w600,
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFFEC4899), // Pink
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const _AuthWrapper(),
      routes: {
        OnboardingScreen.id: (context) => const OnboardingScreen(),
        HomeScreen.id: (context) => HomeScreen(),
        LoginScreen.id: (context) => LoginScreen(),
        SignUpScreen.id: (context) => SignUpScreen(),
        WelcomeScreen.id: (context) => WelcomeScreen(),
        ProgramListScreen.id: (context) => const ProgramListScreen(),
        ChallengeListScreen.id: (context) => const ChallengeListScreen(),
        ProgressDashboardScreen.id: (context) => const ProgressDashboardScreen(),
        WalkthroughScreen.id: (context) => const WalkthroughScreen(),
      },
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await TokenStorage.getAccessToken();
    
    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, OnboardingScreen.id);
      }
      return;
    }

    try {
      final enrollments = await RecoveryService.getUserEnrollments();
      if (mounted) {
        if (enrollments.isEmpty) {
          Navigator.pushReplacementNamed(context, WalkthroughScreen.id);
        } else {
          Navigator.pushReplacementNamed(context, HomeScreen.id);
        }
      }
    } catch (e) {
      // If error (e.g. 401), go to login/onboarding
      if (mounted) {
        Navigator.pushReplacementNamed(context, OnboardingScreen.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}