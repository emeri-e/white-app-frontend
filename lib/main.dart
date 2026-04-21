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
    final token = await TokenStorage.getAccessToken();
    
    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, OnboardingScreen.id);
      }
      return;
    }

    try {
      // 1. Critical: Get Profile. If this fails, we likely have an auth issue.
      await ProfileService.getProfile();
    } catch (e) {
      debugPrint("Critical Error: Profile fetch failed. Redirecting to Onboarding. Error: $e");
      if (mounted) {
        Navigator.pushReplacementNamed(context, OnboardingScreen.id);
      }
      return;
    }

    // 2. Secondary: Enrollments and Dashboard. 
    // We try to get these, but if they fail, we still want to show the Home screen if possible.
    List<dynamic> enrollments = [];
    try {
      enrollments = await RecoveryService.getUserEnrollments();
      await RecoveryService.getProgressDashboard();
    } catch (e) {
      debugPrint("Warning: Failed to load enrollments/dashboard: $e");
    }

    // 3. Optional: Secondary data to prevent flashes. These should NOT block app entry.
    try {
      await Future.wait([
        RecoveryService.getDailyQuote().catchError((e) => <String, dynamic>{}),
        ProgressService.getMoodHistory().catchError((e) => <MoodEntry>[]),
        SupportGroupService.getCurrentSession().catchError((e) => null),
        SupportGroupService.getGroups().catchError((e) => <SupportGroup>[]),
        RecoveryService.getDailyLearningSummary().catchError((e) => <String, dynamic>{}),
        CommunityService().getPosts().catchError((e) => <CommunityPost>[]),
      ]);
    } catch (e) {
      debugPrint("Warning: Some secondary data failed. Moving on. Error: $e");
    }
    
    // 4. Guaranteed animation visibility
    await Future.delayed(const Duration(milliseconds: 3000));

    if (mounted) {
      setState(() {
        // Only show walkthrough if they have absolutely NO enrollments.
        // For existing users who just haven't enrolled in a specific program, 
        // they should still go to Home if they've seen the app before.
        _needsWalkthrough = enrollments.isEmpty;
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