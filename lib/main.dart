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
import 'package:whiteapp/features/feedback/screens/feedback_screen.dart';
import 'package:whiteapp/features/profile/screens/public_profile_screen.dart';
import 'package:whiteapp/features/tools/screens/tools_hub_screen.dart';
import 'package:whiteapp/features/tools/screens/breathing_screen.dart';
import 'package:whiteapp/features/tools/screens/grounding_screen.dart';
import 'package:whiteapp/features/tools/screens/urge_surfing_screen.dart';
import 'package:whiteapp/features/tools/screens/flash_cards_screen.dart';
import 'package:whiteapp/features/tools/screens/manage_decks_screen.dart';
import 'package:whiteapp/features/tools/screens/soundscape_screen.dart';

import 'package:provider/provider.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/core/services/community_service.dart';
import 'package:whiteapp/core/services/token_storage.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:whiteapp/core/widgets/splash_animation.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:whiteapp/features/progress/models/mood_entry.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';
import 'package:whiteapp/features/community/models/community_post.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        FeedbackScreen.id: (context) => const FeedbackScreen(),
        ToolsHubScreen.id: (context) => const ToolsHubScreen(),
        BreathingScreen.id: (context) => const BreathingScreen(),
        GroundingScreen.id: (context) => const GroundingScreen(),
        UrgeSurfingScreen.id: (context) => const UrgeSurfingScreen(),
        FlashCardsScreen.id: (context) => const FlashCardsScreen(),
        ManageDecksScreen.id: (context) => const ManageDecksScreen(),
        SoundscapeScreen.id: (context) => const SoundscapeScreen(),
        '/public-profile': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as int;
          return PublicProfileScreen(userId: userId);
        },
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
  bool _isReady = false;
  bool _isAuthChecked = false;
  bool _needsWalkthrough = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final startTime = DateTime.now();
    const minSplashDuration = Duration(milliseconds: 2500);
    
    // Global safety timeout to prevent hanging on splash
    final safetyTimeout = Future.delayed(const Duration(seconds: 10)).then((_) {
      if (!_isReady && mounted) {
        debugPrint("Safety Timeout Triggered: Initializing app partially.");
        setState(() {
          _isAuthChecked = true;
          _isReady = true;
        });
      }
    });

    try {
      final token = await TokenStorage.getAccessToken().timeout(const Duration(seconds: 5));
      
      if (token == null) {
        _finishLoading(startTime, minSplashDuration, needsOnboarding: true);
        return;
      }

      try {
        // 1. Critical: Get Profile.
        await ProfileService.getProfile();
      } catch (e) {
        debugPrint("Critical Error: Profile fetch failed. Redirecting to Onboarding. Error: $e");
        _finishLoading(startTime, minSplashDuration, needsOnboarding: true);
        return;
      }

      // 2. Secondary/Optional data fetches
      try {
        final enrollments = await RecoveryService.getUserEnrollments().timeout(const Duration(seconds: 5));
        await RecoveryService.getProgressDashboard().timeout(const Duration(seconds: 5));
        
        // Optional: Secondary data. Awaiting this ensures it's cached before Home screen shows.
        await Future.wait([
          RecoveryService.getDailyQuote().catchError((e) => <String, dynamic>{}),
          ProgressService.getMoodHistory().catchError((e) => <MoodEntry>[]),
          SupportGroupService.getCurrentSession().catchError((e) => null),
          SupportGroupService.getGroups().catchError((e) => <SupportGroup>[]),
          RecoveryService.getDailyLearningSummary().catchError((e) => <String, dynamic>{}),
          CommunityService().getPosts().catchError((e) => <CommunityPost>[]),
        ]).timeout(const Duration(seconds: 3)).catchError((e) {
          debugPrint("Note: Secondary data took too long or failed.");
          return [];
        });

        _finishLoading(startTime, minSplashDuration, needsWalkthrough: enrollments.isEmpty);
      } catch (e) {
        debugPrint("Warning: Failed to load enrollments/dashboard: $e");
        _finishLoading(startTime, minSplashDuration);
      }
    } catch (e) {
      debugPrint("Auth Check Failed with Error: $e");
      _finishLoading(startTime, minSplashDuration, needsOnboarding: true);
    }
  }

  void _finishLoading(DateTime startTime, Duration minDuration, {bool needsOnboarding = false, bool needsWalkthrough = false}) async {
    final elapsed = DateTime.now().difference(startTime);
    final remaining = minDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    if (needsOnboarding) {
      Navigator.pushReplacementNamed(context, OnboardingScreen.id);
    } else {
      setState(() {
        _needsWalkthrough = needsWalkthrough;
        _isAuthChecked = true;
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthChecked) {
      return const SplashAnimation();
    }

    return Stack(
      children: [
        // Background App
        if (_needsWalkthrough)
          const WalkthroughScreen()
        else
          HomeScreen(),
          
        // Overlay Splash (Fade out when ready)
        if (!_isReady)
          const SplashAnimation()
        else
          const SizedBox.shrink(),
      ],
    );
  }
}