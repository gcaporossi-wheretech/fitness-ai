# API Contract — FitnessAI Backend

## Base URL
- Development: `http://localhost` (Traefik gateway, path-based routing)
- Production: `https://fitnessai.app` (Traefik gateway, path-based routing)

All endpoints are routed by Traefik based on path prefix:
- `/auth/*` -> auth service (port 8001)
- `/workouts/*` -> workouts service (port 8002)
- `/ai/*` -> ai service (port 8003)
- `/analytics/*` -> analytics service (port 8004)

## Authentication
All protected endpoints require header: `Authorization: Bearer <jwt_token>`

## Error format
All errors return JSON:
```json
{
  "detail": "Human-readable error message",
  "code": "ERROR_CODE",
  "errors": [{"field": "email", "message": "Invalid format"}]
}
```

## HTTP Status codes
- 200: Success
- 201: Created
- 400: Validation error
- 401: Not authenticated
- 403: Not authorized
- 404: Not found
- 409: Conflict (sync)
- 422: Unprocessable entity
- 429: Rate limited
- 500: Internal server error

## Pagination
List endpoints support: `?page=1&per_page=20`
Response includes: `{"items": [...], "total": N, "page": 1, "per_page": 20, "pages": N}`

## Endpoints summary

### Auth (/auth)
- POST /register — {email, password, name, language} -> {user, tokens}
- POST /login — {email, password} -> {access_token, refresh_token}
- POST /refresh — {refresh_token} -> {access_token, refresh_token}
- GET /me — -> {user profile}
- PATCH /me — {name?, age?, goals?, limitations?, language?} -> {user}
- GET /credits — -> {credits: N, history: [...]}
- GET /me/export — -> {all user data as JSON}
- DELETE /me — -> 204 (deletes account and all data)

### Workouts (/workouts)
- GET /plans — -> {items: [plan...], pagination}
- POST /plans — {name, days, phases?, description?} -> {plan}
- GET /plans/{id} — -> {plan with full details}
- PATCH /plans/{id} — {partial plan data} -> {plan}
- DELETE /plans/{id} — -> 204
- GET /sessions — ?from=date&to=date&page=N -> {items: [session...], pagination}
- POST /sessions — {session data} -> {session}
- POST /sync — {sessions: [...]} -> {results: [{client_id, status, server_id}...]}
- GET /exercises — ?muscle_group=X&equipment=Y -> {items: [exercise...]}

### AI (/ai)
- POST /vision/scan — multipart(image) -> {equipment_name, brand, exercises: [...]}
- POST /coach/generate — multipart(photos[], data: JSON) -> {plan}
- GET /vision/history — -> {items: [scan...], pagination}
- GET /coach/history — -> {items: [generation...], pagination}

### Analytics (/analytics)
- GET /progress/{exercise_id} — ?from=date&to=date -> {data_points: [...]}
- GET /volume — ?from=date&to=date&group_by=week -> {data_points: [...]}
- GET /adherence — ?from=date&to=date -> {planned: N, completed: N, rate: 0.85}
- GET /summary — -> {total_sessions, total_volume, streak, favorite_exercise, ...}

### System
- GET /health — -> {status: "ok", version: "x.y.z", db: "ok", ai: "ok"}
