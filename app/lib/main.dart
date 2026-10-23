import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fitness_ai/core/locale_provider.dart';
import 'package:fitness_ai/core/platform/page_reload.dart';
import 'package:fitness_ai/core/router/app_router.dart';
import 'package:fitness_ai/core/storage/hive_storage.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_theme.dart';
import 'package:fitness_ai/l10n/generated/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Inter is bundled in assets/google_fonts: never download it at startup.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Render immediately; Hive is opened by AppBootstrap so a slow or stuck
  // IndexedDB (iOS Safari PWA) never leaves the user on a blank screen.
  runApp(const ProviderScope(child: AppBootstrap()));
}

/// Opens offline storage, then shows the app.
/// Shows a spinner while opening and a retry screen on failure or timeout.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  static const initTimeout = Duration(seconds: 10);

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _init = _openStorage();

  Future<void> _openStorage() =>
      HiveStorage.init().timeout(AppBootstrap.initTimeout);

  void _retry() {
    // A hung IndexedDB open can't be retried in-page: reload on web.
    if (canReloadPage) {
      reloadPage();
      return;
    }
    setState(() => _init = _openStorage());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const FitnessAIApp();
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Impossibile avviare l\'app.\n'
                            'Tocca Riprova per ricaricarla.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _retry,
                            child: const Text('Riprova'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }
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
