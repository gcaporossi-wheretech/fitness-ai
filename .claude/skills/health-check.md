# Skill: health-check

Verifies the health status of all microservices and infrastructure. Use before starting development work to ensure everything is running correctly, or when debugging connectivity issues.

## Steps
1. Check Docker containers status: `docker compose ps`
2. Verify Traefik gateway: `curl http://localhost:80/`
3. Verify auth service: `curl http://localhost:80/auth/health`
4. Verify workouts service: `curl http://localhost:80/workouts/health`
5. Verify AI service: `curl http://localhost:80/ai/health`
6. Verify analytics service: `curl http://localhost:80/analytics/health`
7. Verify database: `docker compose exec db pg_isready`
8. Verify Redis: `docker compose exec redis redis-cli ping`
9. Verify web dashboard: `curl http://localhost:80/`
10. Check recent logs for errors: `docker compose logs --tail=20`
11. Report status of each service: OK / DOWN / DEGRADED
12. If any service is down, suggest specific fix steps
