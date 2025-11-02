import 'package:flutter/material.dart';

/// Branded splash used while the app finishes bootstrapping.
class BrandedSplashScreen extends StatelessWidget {
  const BrandedSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headlineStyle = theme.textTheme.headlineMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      height: 1.15,
      shadows: const [
        Shadow(blurRadius: 10, color: Colors.black54, offset: Offset(0, 4)),
      ],
    );

    final subtitleStyle = theme.textTheme.titleMedium?.copyWith(
      color: Colors.white70,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1C3A), Color(0xFF182B5A), Color(0xFF21406F)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Erudite\nData Collection',
                            style: headlineStyle,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Smart field intelligence for reliable customer insights.',
                            style: subtitleStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Developed by LabSity Technologies Nigeria Limited',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
