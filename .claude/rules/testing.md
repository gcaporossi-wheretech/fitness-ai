# Testing Rules
Applies to: **/*test*.*

## Coverage requirements
- Backend (Python): minimum 80% coverage
- Frontend (Flutter): minimum 70% coverage
- Dashboard (Next.js): minimum 70% coverage
- AI module: 90% coverage on prompt/response handling logic

## Test categories
- **Unit tests**: every service, model, utility — no external dependencies
- **Integration tests**: API endpoints with test database
- **Contract tests**: API response schemas match documented OpenAPI spec
- **E2E tests**: critical user flows (login -> create workout -> track -> sync)

## Naming and organization
- Python: `test_<module>_<function>_<scenario>.py`
- Dart: `<filename>_test.dart` mirroring source structure
- TypeScript: `<filename>.test.ts` or `<filename>.test.tsx`
- Test data: fixtures directory, never hardcoded in test body

## Principles
- Tests must be deterministic — no reliance on timing or external services
- Mock external APIs (Claude API) in tests — never call real APIs
- Each test independent — no shared mutable state between tests
- Test the behavior, not the implementation
- Failed test = blocked merge — no exceptions
