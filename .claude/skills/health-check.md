# Skill: health-check

Verifies the health status of all project services and development environment. Use before starting development work to ensure everything is running correctly, or when debugging connectivity issues.

## Steps
1. Check Docker containers status: `docker compose ps`
2. Verify API health: `curl http://localhost:8000/health`
3. Verify database connection: `docker compose exec db pg_isready`
4. Verify web dashboard: `curl http://localhost:3000`
5. Check recent logs for errors: `docker compose logs --tail=20`
6. Report status of each service: OK / DOWN / DEGRADED
7. If any service is down, suggest specific fix steps
