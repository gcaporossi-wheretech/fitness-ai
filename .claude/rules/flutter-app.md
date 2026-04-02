# Flutter App Rules
Applies to: app/**/*.dart

## Architecture
- Clean Architecture: `lib/features/<name>/presentation|domain|data`
- State management: Riverpod 3.x with Notifier (not StateNotifier — deprecated)
- Models: freezed + json_serializable for all data classes
- Repository pattern: abstract interface + implementation (Hive for local, API for remote)

## Code style
- Dart naming: camelCase variables, PascalCase classes, snake_case files
- Widgets: prefer StatelessWidget, use ConsumerWidget for Riverpod
- Max widget build method: ~50 lines — extract sub-widgets
- Document every public class and method with `///` doc comments

## Offline-first
- Hive as primary storage, API sync as secondary
- Every write goes to Hive first, then queues for sync
- Conflict resolution: last-write-wins with timestamp
- App must be fully functional without network

## Testing
- Widget tests for every screen
- Unit tests for every service and repository
- Integration tests for sync logic
- Use mocktail for mocking

## Design
- Dark mode as primary (AppColors, AppTheme from design system)
- Reuse existing widgets: GlassmorphismCard, GlowButton, BigNumber, NeonText
- Spacing via AppSpacing constants — no magic numbers
