import 'package:flutter/material.dart';
import '../../../core/common_widgets/app_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_strings.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withAlpha(35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    size: 72,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reuniting families when they need each other most.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey, fontSize: 15),
                ),
                const SizedBox(height: 44),
                AppButton(
                  text: 'Login as Normal User',
                  onPressed: () =>
                      Navigator.pushNamed(context, '/login_normal'),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Login as Official',
                  color: AppTheme.secondaryColor,
                  onPressed: () =>
                      Navigator.pushNamed(context, '/login_official'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
