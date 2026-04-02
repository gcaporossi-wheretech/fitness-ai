# Skill: session-start

Rebuilds full project context at the beginning of a new Claude session. Use when opening Claude Code on this project after any break, to understand current state, active tasks, and what to work on next.

## Steps
1. Read CLAUDE.md for architecture overview (7 containers, 4 microservices)
2. Run `git log --oneline -15` to see recent commits and understand momentum
3. Check GitHub Issues for any task labeled "in-progress" or the most recently closed issue
4. Read docs/ for any recent architecture changes
5. Check which services exist in services/ and their current state
6. Summarize: current state, active task (if any), next task from backlog, any blockers
7. If a task is in progress, identify the exact service and files being modified and continue from there
