import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/history/data/history_repository.dart';
import 'package:fitness_ai/features/history/presentation/session_detail_screen.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// Calendar view showing workout days and scheduling.
/// Displays a monthly calendar with workout sessions marked,
/// and allows selecting a date to see session details.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedMonth;
  DateTime? _selectedDate;
  Map<DateTime, List<WorkoutSession>> _sessionsByDate = {};

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadSessions();
  }

  void _loadSessions() {
    final repo = ref.read(historyRepositoryProvider);
    final sessions = repo.getLocalSessions();
    final grouped = <DateTime, List<WorkoutSession>>{};
    for (final session in sessions) {
      final key = DateTime(
          session.startedAt.year, session.startedAt.month, session.startedAt.day);
      grouped.putIfAbsent(key, () => []).add(session);
    }
    setState(() => _sessionsByDate = grouped);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun
    final daysInMonth = lastDayOfMonth.day;
    final monthName = DateFormat('MMMM yyyy', 'it').format(_selectedMonth);

    final selectedSessions = _selectedDate != null
        ? (_sessionsByDate[_selectedDate] ?? [])
        : <WorkoutSession>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: SafeArea(
        child: Column(
          children: [
            // Month navigation
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                  ),
                  Text(
                    monthName.substring(0, 1).toUpperCase() +
                        monthName.substring(1),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),
            // Day of week headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Calendar grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _buildCalendarGrid(
                firstDayOfMonth,
                startWeekday,
                daysInMonth,
                today,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Selected date sessions
            if (_selectedDate != null) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      DateFormat('d MMMM', 'it').format(_selectedDate!),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${selectedSessions.length} sessioni',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Expanded(
              child: selectedSessions.isEmpty
                  ? Center(
                      child: Text(
                        _selectedDate != null
                            ? 'Nessun allenamento in questo giorno'
                            : 'Seleziona un giorno per vedere i dettagli',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      itemCount: selectedSessions.length,
                      itemBuilder: (context, index) {
                        final session = selectedSessions[index];
                        return GlassmorphismCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SessionDetailScreen(session: session),
                            ),
                          ),
                          child: Row(
                            children: [
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
                                      '${session.formattedDuration} - ${session.totalCompletedSets} serie',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(
    DateTime firstDay,
    int startWeekday,
    int daysInMonth,
    DateTime today,
  ) {
    final cells = <Widget>[];

    // Empty cells before first day
    for (var i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    // Day cells
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final isToday = date == today;
      final isSelected = date == _selectedDate;
      final hasSessions = _sessionsByDate.containsKey(date);

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : date.isAfter(today)
                            ? AppColors.textDisabled
                            : AppColors.textPrimary,
                    fontWeight:
                        isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                if (hasSessions)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: cells,
    );
  }
}
