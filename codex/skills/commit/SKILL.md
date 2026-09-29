---
name: commit
description: Choose and apply the repository's commit convention when the user asks to commit, draft a commit message, or review staged changes.
---

# Commit

Use this skill for explicit commit requests, `/commit`, commit-message drafting, or staged-change review. It does not authorize staging, committing, rewriting history, or pushing beyond the user's request.

## Scope

Determine the repository scope with `git remote get-url origin` before writing a message.

| Origin | Convention |
| --- | --- |
| `github.com/joresserwe/*` with no upstream flow elsewhere | This skill's personal convention |
| No remote | This skill's personal convention |
| Any other owner, or a fork sending changes to `upstream` | The repository's own enforced/history convention |

For another repository, inspect enforced rules first (`CONTRIBUTING.md`, `.gitmessage`, commitlint, hooks, and PR templates), then sample `git log --oneline -30` and match the observed prefix, scope, capitalization, tense, length, body, and trailers. In the Korean plan, state the convention and its evidence. Do not impose this skill on another owner's project.

## Personal convention

Use one English line under 72 characters: a capitalized imperative verb followed by a concise summary. Do not use conventional prefixes (`feat:`, `fix:`, and similar), a body, or trailers unless the user asks.

Check the rows top to bottom and use the first one that describes the change's main purpose.

| Verb | Use for |
| --- | --- |
| Fix | Correcting something that was wrong when written (bug, typo, wrong value or fact) |
| Update | Bringing something that went stale up to date (versions, dependencies, code or docs that no longer match the current state) |
| Prevent | Blocking undesired behavior that comes from outside the repo (another app, the OS, a tool) |
| Use | Switching to a different tool, library, or approach |
| Add | New code, features, files, tests, or documents |
| Remove | Deleting code, files, or features |
| Rename | Only renaming (variables, files, functions) |
| Move | Only relocating code or files |
| Set | Only changing values (config values, flags, options) |
| Refactor | Restructuring or simplifying without changing behavior |
| Make | Any other change to existing code, config, or docs |

Make is the catch-all last row, so every change has a table verb; never use an off-table verb.

## Workflow

1. Check the remote, repository rules, status, and diff. Keep unrelated user changes out of the proposed commit.
2. Group changes into coherent commits and present a Korean plan. For each message, include its files and inline evidence: the personal verb row, or the other repository's observed convention and source.
3. Flag unusual, generated, debug, or sensitive files.
4. Do not ask the user to reconfirm scope they already requested or approved. For any new mutation outside that scope, present the concrete plan and ask before staging or committing. Push only after an explicit push request.
5. After the required authorization, execute the approved commits in order and report the resulting hashes and checks.

Never add `Co-Authored-By` or any attribution trailer. Preserve another repository's enforced rules and history even when they differ from this personal convention.
