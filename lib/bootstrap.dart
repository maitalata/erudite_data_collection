import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/env.dart';
import 'core/database/local_database.dart';
import 'core/providers.dart';
import 'app.dart';
import 'core/widgets/branded_splash_screen.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  final localDatabase = await LocalDatabase.create();

  runApp(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(localDatabase)],
      child: Builder(
        builder: (context) {
          // Show branded splash for a short duration then start app
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const _SplashBoot(),
          );
        },
      ),
    ),
  );
}

class _SplashBoot extends StatefulWidget {
  const _SplashBoot({Key? key}) : super(key: key);

  @override
  State<_SplashBoot> createState() => _SplashBootState();
}

class _SplashBootState extends State<_SplashBoot> {
  @override
  void initState() {
    super.initState();
    // Keep splash visible briefly while app finishes boot logic.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      // Replace splash with actual application shell.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            return const EruditeApp();
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const BrandedSplashScreen();
  }
}
