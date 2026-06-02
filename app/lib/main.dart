import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/locale_provider.dart';
import 'package:fitness_ai/core/router/app_router.dart';
import 'package:fitness_ai/core/storage/hive_storage.dart';
import 'package:fitness_ai/core/theme/app_theme.dart';
import 'package:fitness_ai/l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline-first storage
  await HiveStorage.init();

  runApp(const ProviderScope(child: FitnessAIApp()));
}

/// Root application widget.
class FitnessAIApp extends ConsumerWidget {
  const FitnessAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'FitnessAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      locale: locale,
    );
  }
}
