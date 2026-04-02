# Skill: session-save

Saves current session context to memory before ending work. Use at the end of every Claude session, or before a long break, to ensure continuity in the next session.

## Steps
1. Summarize what was accomplished in this session (tasks completed, files modified)
2. Note the current task state (done, in-progress with % estimate, blocked)
3. List any decisions made during the session that affect architecture or design
4. Record next steps: what to do first in the next session
5. Save all of this to /memory with structured format
6. If any docs/ pages need updating based on session work, note them as pending
