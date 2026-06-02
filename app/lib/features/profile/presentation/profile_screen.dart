import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/auth/domain/auth_state.dart';
import 'package:fitness_ai/features/auth/presentation/auth_notifier.dart';

/// User profile screen with account info and settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                'Profilo',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (authState case AuthState())
                _buildProfileContent(context, ref, authState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
  ) {
    // Extract user if authenticated - for now show placeholder
    return Expanded(
      child: Column(
        children: [
          GlassmorphismCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    size: 30,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Utente',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '0 crediti AI',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            label: 'Impostazioni',
            onTap: () {},
          ),
          _buildMenuItem(
            context,
            icon: Icons.download,
            label: 'Esporta Dati',
            onTap: () {},
          ),
          _buildMenuItem(
            context,
            icon: Icons.language,
            label: 'Lingua',
            onTap: () {},
          ),
          if (ref.read(authNotifierProvider.notifier).webauthnSupported)
            _buildMenuItem(
              context,
              icon: Icons.face_retouching_natural,
              label:
                  ref.read(authNotifierProvider.notifier).hasWebAuthnCredential
                      ? 'Face ID attivo'
                      : 'Abilita Face ID',
              onTap: () => _enableFaceId(context, ref),
            ),
          const Spacer(),
          GlowButton(
            label: 'Esci',
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
            color: AppColors.error,
            icon: Icons.logout,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _enableFaceId(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(authNotifierProvider.notifier);
    if (notifier.hasWebAuthnCredential) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Face ID è già attivo su questo dispositivo'),
      ));
      return;
    }
    messenger.showSnackBar(const SnackBar(
      content: Text('Conferma con il volto / impronta...'),
    ));
    try {
      await notifier.enableWebAuthn();
      messenger.showSnackBar(const SnackBar(
        content: Text('Face ID attivato! Ora puoi accedere col volto.'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Face ID non attivato: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GlassmorphismCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
