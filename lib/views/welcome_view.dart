import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import 'login_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    // FIRST SCREEN
    OnboardingPage(
      title: '',
      subtitle:
          'Your trusted platform for rotating savings and credit associations. Save together, grow together.',
      icon: Icons.savings,
      iconColor: const Color(0xFF2563EB),
      isFirstScreen: true,
    ),
    // SECOND SCREEN
    OnboardingPage(
      title: 'What is Paluwagan?',
      subtitle:
          'Paluwagan is an informal Filipino rotating savings and credit association (ROSCA) where members contribute a fixed amount regularly, and each receives the total pot in turn. Often based on trust among colleagues or friends, it serves as a community-based, interest-free method for accumulating savings or securing a lump sum.\n\n"PaluwaganPro brings this traditional Filipino practice into the digital age, making it easier to manage, track, and maintain trust within your savings groups."',
      icon: Icons.info_outline,
      iconColor: const Color(0xFF2563EB),
      isFirstScreen: false,
    ),
    // THIRD SCREEN
    OnboardingPage(
      title: 'Why Choose PaluwaganPro?',
      features: [
        FeatureItem(
          title: 'Community-Based',
          description:
              'Join paluwagan groups with trusted friends, family, or colleagues',
          icon: Icons.people_alt_outlined,
        ),
        FeatureItem(
          title: 'Transparent Tracking',
          description:
              'Monitor all contributions, payouts, and schedules in real-time',
          icon: Icons.track_changes_outlined,
        ),
        FeatureItem(
          title: 'Interest-Free',
          description:
              'No hidden fees or interest - traditional Filipino savings method',
          icon: Icons.money_off_outlined,
        ),
      ],
      icon: Icons.star_outline,
      iconColor: const Color(0xFF2563EB),
      isFirstScreen: false,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _pages[index];
                  },
                ),
              ),

              // Page Indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? colorScheme.primary
                            : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Get Started Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _navigateToLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '© 2026 PaluwaganPro. Building trust in Filipino communities.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final List<FeatureItem>? features;
  final bool isFirstScreen;

  const OnboardingPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.features,
    required this.isFirstScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TOP SPACING - Mas dako para ibaba ang logo
            SizedBox(height: isFirstScreen ? 220 : 16),

            // Logo
            Container(
              height: isFirstScreen ? 200 : 180,
              width: isFirstScreen ? 200 : 180,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      icon,
                      size: isFirstScreen ? 1 : 80,
                      color: iconColor,
                    );
                  },
                ),
              ),
            ),

            // SPACING AFTER LOGO - Mas dako para ibaba ang text
            SizedBox(height: isFirstScreen ? 60 : 16),

            // Title (kung naa)
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // Subtitle/Description - Mas dako nga text
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: isFirstScreen ? 16 : 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

            // Features (para sa third screen)
            if (features != null) ...[
              const SizedBox(height: 20),
              ...features!.map(
                (feature) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        feature.icon,
                        color: const Color(0xFF2563EB),
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feature.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class FeatureItem {
  final String title;
  final String description;
  final IconData icon;

  FeatureItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}
