import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Keep splash visible a bit longer so it’s noticeable.
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Route based on real auth + whether a profile exists.
      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        final user = authProvider.user;
        if (user != null) {
          // Guard against Firestore/network issues so we don't hang on splash.
          try {
            await userProvider
                .loadCurrentUser(user.uid)
                .timeout(const Duration(seconds: 8));
          } catch (e) {
            debugPrint('Error loading current user on splash: $e');
          }
        }

        if (!mounted) return;

        final hasProfile = userProvider.currentUser != null;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                hasProfile ? const HomeScreen() : const ProfileSetupScreen(),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      // As a fallback, go to login instead of staying stuck on splash.
      debugPrint('Error in _checkAuthStatus: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sports_soccer,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'RosterUp',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Organize your games',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
