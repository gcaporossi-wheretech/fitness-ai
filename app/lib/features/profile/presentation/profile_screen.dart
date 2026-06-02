import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/auth/webauthn.dart' as webauthn;
import 'package:fitness_ai/core/disclaimer.dart';
import 'package:fitness_ai/core/locale_provider.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/auth/domain/auth_state.dart';
import 'package:fitness_ai/features/auth/domain/user.dart';
import 'package:fitness_ai/features/auth/presentation/auth_notifier.dart';

/// User profile screen with account info and settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text('Profilo', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _content(context, ref, user)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, User? user) {
    final notifier = ref.read(authNotifierProvider.notifier);
    final displayName = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!
        : (user?.email ?? 'Utente');

    return Column(
      children: [
        GlassmorphismCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.person, size: 30, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    if (user?.email != null && displayName != user!.email) ...[
                      const SizedBox(height: 2),
                      Text(user.email,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.xs),
                        Text('${user?.aiCredits ?? 0} crediti AI',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _menuItem(context,
            icon: Icons.settings,
            label: 'Impostazioni',
            onTap: () => _showSettings(context, user)),
        _menuItem(context,
            icon: Icons.download,
            label: 'Esporta Dati',
            onTap: () => _exportData(context, ref)),
        _menuItem(context,
            icon: Icons.language,
            label: 'Lingua (${ref.watch(localeProvider).languageCode.toUpperCase()})',
            onTap: () => _showLanguage(context, ref)),
        if (notifier.webauthnSupported)
          _menuItem(context,
              icon: Icons.face_retouching_natural,
              label: notifier.hasWebAuthnCredential
                  ? 'Face ID attivo'
                  : 'Abilita Face ID',
              onTap: () => _enableFaceId(context, ref)),
        _menuItem(context,
            icon: Icons.shield_outlined,
            label: 'Disclaimer e Privacy',
            onTap: () => showDisclaimerDialog(context)),
        const Spacer(),
        GlowButton(
          label: 'Esci',
          onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          color: AppColors.error,
          icon: Icons.logout,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  // -------- Actions --------

  void _showSettings(BuildContext context, User? user) {
    String d(DateTime? x) =>
        x == null ? '-' : '${x.day}/${x.month}/${x.year}';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Email', user?.email ?? '-'),
            _infoRow('Crediti AI', '${user?.aiCredits ?? 0}'),
            _infoRow('Lingua', (user?.language ?? 'it').toUpperCase()),
            _infoRow('Iscritto dal', d(user?.createdAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Esportazione in corso...')));
    try {
      final data = await ref.read(authNotifierProvider.notifier).exportData();
      webauthn.downloadFile(
        'fitnessai-export.json',
        const JsonEncoder.withIndent('  ').convert(data),
      );
      messenger.showSnackBar(const SnackBar(
        content: Text('Dati esportati — download avviato'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Export non riuscito: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _showLanguage(BuildContext context, WidgetRef ref) {
    final current = ref.read(localeProvider).languageCode;
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Lingua'),
        children: [
          _langTile(ctx, ref, 'it', 'Italiano', current),
          _langTile(ctx, ref, 'en', 'English', current),
        ],
      ),
    );
  }

  Widget _langTile(
      BuildContext ctx, WidgetRef ref, String code, String label, String current) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(localeProvider.notifier).setLanguage(code);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(
            current == code
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
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

  // -------- Widgets --------

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _menuItem(
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
