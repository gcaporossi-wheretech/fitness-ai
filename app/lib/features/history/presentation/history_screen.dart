import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/history/data/history_repository.dart';
import 'package:fitness_ai/features/history/presentation/session_detail_screen.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// Screen showing workout history with a list of past sessions.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<WorkoutSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final repo = ref.read(historyRepositoryProvider);
    // Show the local cache immediately...
    setState(() {
      _sessions = repo.getLocalSessions();
      _loading = false;
    });
    // ...then refresh from the server and merge, so history is recovered even
    // if the local cache was wiped (e.g. after reinstalling the PWA). Offline
    // failures are ignored — the local list stays visible.
    try {
      await repo.fetchSessions();
      if (mounted) {
        setState(() => _sessions = repo.getLocalSessions());
      }
    } catch (_) {
      // offline or server error: keep showing the local cache
    }
  }

  Future<bool> _confirmDelete(WorkoutSession session) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Eliminare la sessione?'),
        content: Text(
            '${session.dayName ?? 'Workout'} verrà rimossa dallo storico.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _deleteSession(WorkoutSession session) async {
    // Remove from the in-memory list first so the Dismissible is consistent.
    setState(() =>
        _sessions = _sessions.where((s) => s.id != session.id).toList());
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(historyRepositoryProvider).deleteSession(session.id);
    messenger.showSnackBar(
      const SnackBar(content: Text('Sessione eliminata')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy', 'it');

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: GradientText(
              'Storico',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : _sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history,
                                size: 48,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'Nessun allenamento registrato',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Completa il tuo primo workout!',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadSessions(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            return Dismissible(
                              key: ValueKey(session.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmDelete(session),
                              onDismissed: (_) => _deleteSession(session),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(
                                    right: AppSpacing.lg),
                                margin: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: AppColors.error),
                              ),
                              child: StaggeredListItem(
                              index: index,
                              child: GlassmorphismCard(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SessionDetailScreen(
                                          session: session),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    // Date badge
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.heroGradient,
                                        borderRadius:
                                            BorderRadius.circular(
                                                AppSpacing.radiusMd),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${session.startedAt.day}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.dayName ?? 'Workout',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Text(
                                            dateFormat.format(
                                                session.startedAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          session.formattedDuration,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                  color: AppColors.primary),
                                        ),
                                        Text(
                                          '${session.totalCompletedSets} serie',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    const Icon(Icons.chevron_right,
                                        color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
