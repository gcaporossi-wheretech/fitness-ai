# Skill: create-github-issue

Creates a new GitHub Issue linked to documentation when a new task emerges during development. Use when you discover a bug, identify technical debt, or realize a new task is needed that was not in the original backlog.

## Parameters
- title: Issue title in format "[Component] Action description"
- labels: comma-separated labels (bug, enhancement, infra, security, etc.)
- phase: which development phase (1-foundation, 2-vertical-slice, 3-completion, 4-hardening)
- doc_reference: path to relevant docs/ file

## Steps
1. Create the issue with `gh issue create` including title, body with doc reference, and labels
2. Add the issue to the GitHub Project board if one exists
3. Log the issue number for reference in commits
