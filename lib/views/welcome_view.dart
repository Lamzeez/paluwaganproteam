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

  final List<OnboardingPageData> _pages = [
    const OnboardingPageData(
      title: '',
      subtitle:
          'Your trusted platform for rotating savings and credit associations. Save together, grow together.',
      icon: Icons.savings,
      iconColor: Color(0xFF2563EB),
      isFirstScreen: true,
    ),
    const OnboardingPageData(
      title: 'What is Paluwagan?',
      subtitle:
          'Paluwagan is an informal Filipino rotating savings and credit association (ROSCA) where members contribute a fixed amount regularly, and each receives the total pot in turn. Often based on trust among colleagues or friends, it serves as a community-based, interest-free method for accumulating savings or securing a lump sum.\n\n"PaluwaganPro brings this traditional Filipino practice into the digital age, making it easier to manage, track, and maintain trust within your savings groups."',
      icon: Icons.info_outline,
      iconColor: Color(0xFF2563EB),
      isFirstScreen: false,
    ),
    OnboardingPageData(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
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
                        return OnboardingPage(
                          page: _pages[index],
                          availableHeight: constraints.maxHeight,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '© 2026 PaluwaganPro. Building trust in Filipino communities.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final OnboardingPageData page;
  final double availableHeight;

  const OnboardingPage({
    super.key,
    required this.page,
    required this.availableHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isCompactHeight = availableHeight < 760;
    final topSpacing = page.isFirstScreen
        ? (isCompactHeight ? 40.0 : 72.0)
        : (isCompactHeight ? 16.0 : 24.0);
    final logoSize = page.isFirstScreen
        ? (isCompactHeight ? 168.0 : 190.0)
        : (isCompactHeight ? 150.0 : 176.0);
    final spacingAfterLogo = page.isFirstScreen
        ? (isCompactHeight ? 28.0 : 40.0)
        : 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: availableHeight * 0.72),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: topSpacing),
              Container(
                height: logoSize,
                width: logoSize,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        page.icon,
                        size: page.isFirstScreen ? 1 : 80,
                        color: page.iconColor,
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: spacingAfterLogo),
              if (page.title.isNotEmpty) ...[
                Text(
                  page.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              if (page.subtitle != null)
                Text(
                  page.subtitle!,
                  style: TextStyle(
                    fontSize: page.isFirstScreen ? 16 : 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (page.features != null) ...[
                const SizedBox(height: 20),
                ...page.features!.map(
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
              SizedBox(height: page.isFirstScreen ? 24 : 20),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final List<FeatureItem>? features;
  final bool isFirstScreen;

  const OnboardingPageData({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.features,
    required this.isFirstScreen,
  });
}

class FeatureItem {
  final String title;
  final String description;
  final IconData icon;

  const FeatureItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}
