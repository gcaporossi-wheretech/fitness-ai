# Next.js Dashboard Rules
Applies to: web/**/*.{ts,tsx}

## Architecture
- Next.js 14 App Router — no pages/ directory
- TypeScript strict mode — no `any` types
- Server Components by default, `"use client"` only when needed
- API calls via server actions or route handlers — never from client directly

## Code style
- File naming: kebab-case for files, PascalCase for components
- Props: always typed with explicit interface (not inline)
- Components: one component per file, named export matching filename
- Tailwind for styling — no CSS modules, no styled-components

## UI
- shadcn/ui as component library — extend, don't replace
- Dark mode as default (matches mobile app)
- Responsive: mobile-first breakpoints
- Charts: Recharts with consistent color palette from design system

## Security
- JWT stored in httpOnly cookies — never localStorage
- All API calls include auth header via middleware
- CSP headers configured in next.config.js
- No sensitive data in client components

## Testing
- Jest + React Testing Library for component tests
- Test user interactions, not implementation details
