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

| Verb | Use for |
| --- | --- |
| Add | New code, functionality, tests, or documents |
| Fix | Broken behavior, typos, or naming |
| Update | Version, dependency, or resource revisions |
| Remove | Unnecessary code or files |
| Make | Behavior changes |
| Use | Switching tools or approaches |
| Prevent | Avoiding undesired behavior |
| Set | Minor config values or flags |
| Ensure | Guaranteeing a state or behavior |
| Refactor | Structure changes without behavior changes |
| Move | Relocating code |
| Rename | Renaming code or files |

Use the verb that describes the change's nature. If none fits, explain the off-table choice and why the table verbs do not fit in the Korean plan.

## Workflow

1. Check the remote, repository rules, status, and diff. Keep unrelated user changes out of the proposed commit.
2. Group changes into coherent commits and present a Korean plan. For each message, include its files and inline evidence: the personal verb row, or the other repository's observed convention and source.
3. Flag unusual, generated, debug, or sensitive files.
4. Do not ask the user to reconfirm scope they already requested or approved. For any new mutation outside that scope, present the concrete plan and ask before staging or committing. Push only after an explicit push request.
5. After the required authorization, execute the approved commits in order and report the resulting hashes and checks.

Never add `Co-Authored-By` or any attribution trailer. Preserve another repository's enforced rules and history even when they differ from this personal convention.
