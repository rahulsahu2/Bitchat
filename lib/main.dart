import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/services/database/database_service.dart';
import 'core/services/providers.dart';
import 'features/settings/presentation/profile_setup_screen.dart';
import 'features/chat/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eagerly initialize local Isar database service
  final dbService = DatabaseService();
  await dbService.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
      ],
      child: const BitChatApp(),
    ),
  );
}

class BitChatApp extends ConsumerWidget {
  const BitChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(userIdentityProvider);

    return MaterialApp(
      title: 'BitChat Mesh',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: identityAsync.when(
        data: (identity) {
          if (identity == null) {
            return const ProfileSetupScreen();
          }

          // Eagerly trigger background mesh router initialization
          ref.read(meshRouterStateProvider);

          return const HomeScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Failed to load local profile database:\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
