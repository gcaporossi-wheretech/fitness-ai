import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/auth/domain/auth_state.dart';
import 'package:fitness_ai/features/auth/presentation/auth_notifier.dart';

/// Credits management screen showing balance and purchase options.
class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final credits = authState is AuthAuthenticated ? authState.user.aiCredits : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Crediti AI')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              // Balance card
              GlassmorphismCard(
                borderColor: AppColors.primary.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 48, color: AppColors.warning),
                    const SizedBox(height: AppSpacing.md),
                    NeonText(
                      '$credits',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.w900),
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Crediti AI disponibili',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Usage info
              GlassmorphismCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Come funzionano',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CreditUsageRow(
                      icon: Icons.camera_alt,
                      label: 'Vision Scan',
                      cost: '1 credito',
                      description: 'Riconoscimento macchinario da foto',
                    ),
                    _CreditUsageRow(
                      icon: Icons.auto_awesome,
                      label: 'Coach AI',
                      cost: '3 crediti',
                      description: 'Generazione scheda personalizzata',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Purchase options
              Text(
                'Acquista crediti',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _CreditPackage(
                credits: 10,
                price: '2.99',
                popular: false,
                onPurchase: () => _showPurchaseDialog(context),
              ),
              _CreditPackage(
                credits: 30,
                price: '6.99',
                popular: true,
                onPurchase: () => _showPurchaseDialog(context),
              ),
              _CreditPackage(
                credits: 100,
                price: '14.99',
                popular: false,
                onPurchase: () => _showPurchaseDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('In arrivo'),
        content: const Text(
          'Gli acquisti in-app saranno disponibili nella prossima versione.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _CreditUsageRow extends StatelessWidget {
  const _CreditUsageRow({
    required this.icon,
    required this.label,
    required this.cost,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String cost;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyLarge),
                Text(description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              cost,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditPackage extends StatelessWidget {
  const _CreditPackage({
    required this.credits,
    required this.price,
    required this.popular,
    required this.onPurchase,
  });

  final int credits;
  final String price;
  final bool popular;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      onTap: onPurchase,
      borderColor: popular
          ? AppColors.success.withValues(alpha: 0.4)
          : AppColors.primary.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.warning, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$credits crediti',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (popular) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: const Text(
                          'POPOLARE',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${(double.parse(price) / credits * 100).toStringAsFixed(0)} cent/credito',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '\u20AC$price',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
