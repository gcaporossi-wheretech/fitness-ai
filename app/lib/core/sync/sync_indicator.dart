import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/sync/sync_service.dart';

/// Visual indicator showing the current sync status.
/// Shows as a small badge/icon in the app bar or bottom bar.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key, this.showLabel = false});
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(syncServiceProvider);
    final status = syncService.status;

    final (icon, color, label) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done, AppColors.success, 'Sincronizzato'),
      SyncStatus.pending => (Icons.cloud_upload, AppColors.warning, '${syncService.pendingCount} in attesa'),
      SyncStatus.syncing => (Icons.sync, AppColors.primary, 'Sincronizzazione...'),
      SyncStatus.error => (Icons.cloud_off, AppColors.error, 'Errore sync'),
      SyncStatus.offline => (Icons.wifi_off, AppColors.textDisabled, 'Offline'),
    };

    return GestureDetector(
      onTap: () {
        if (status == SyncStatus.pending || status == SyncStatus.error) {
          syncService.syncAll();
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          if (showLabel) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
          if (status == SyncStatus.pending) ...[
            const SizedBox(width: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                '${syncService.pendingCount}',
                style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
