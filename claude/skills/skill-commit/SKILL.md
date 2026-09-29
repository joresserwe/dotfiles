---
name: skill-commit
description: Git commit message convention and commit workflow. Use this skill whenever the user asks to commit, write commit messages, or review staged changes for committing. Also trigger when the user says /commit, "commit this", "make a commit", or any variation of requesting a git commit.
---

# Git Commit Skill

## Scope — decide which convention applies first

The message format in this skill is the **user's personal convention**. It applies only to the user's own repositories. Decide with `git remote get-url origin` before writing any message:

| Origin | Convention to use |
|---|---|
| `github.com/joresserwe/*` — dotfiles, nvim-config, and every other repo under that account | This skill's format (below) |
| No remote configured (local-only repo) | This skill's format (below) |
| Any other owner — work repos, forks, OSS contributions | **That repository's own convention** (see next section) |

A fork of someone else's project counts as "other owner" even when `origin` points at `joresserwe/`: if `upstream` exists and commits flow back there, follow upstream's convention.

Regardless of scope, these always apply: the Commit Workflow, Korean explanations in the commit plan, and the Gotchas.

## Other repositories — derive the convention, don't impose this one

Never apply this skill's format to a repo that has its own. Instead:

1. Check for enforced rules first — `CONTRIBUTING.md`, `.gitmessage`, `commitlint.config.*`, `.husky/commit-msg`, `.github/PULL_REQUEST_TEMPLATE.md`. An enforced rule beats anything inferred from history.
2. Sample the real history: `git log --oneline -30`, plus `git log -10` to see whether bodies, footers, or trailers are used.
3. Match what you find — prefixes (`feat:`, `[JIRA-123]`), scopes, capitalization, tense, line length, body/footer structure, and language.
4. If history is empty or shows no consistent pattern, fall back to this skill's format and say so in the plan.

In the commit plan, replace the verb→table annotation with a one-line statement of the observed convention and the evidence for it (e.g. `convention: conventional-commits, from commitlint.config.js` or `convention: "<verb> <what>" lowercase, from git log -30`). The verb table below applies only to the user's own repos.

## Commit Message Format

Applies to the user's own repositories, per Scope above.

Write commit messages as a **single line** starting with an **imperative English verb** (capitalized), followed by a concise summary. No conventional commit prefixes (`feat:`, `fix:`, etc.). No message body unless explicitly requested.

**Example:**
```
Fix Flow Launcher snapshot reads to decode as UTF-8
Update PATH lookup for pnpm 10 global binaries
Prevent GlazeWM from managing PotPlayer's shadow window
Make 's' key toggleable in which-key settings
Set colorscheme to tokyonight and remove unused files
```

## Verb Selection

Applies to the user's own repositories. Check the rows top to bottom and use the **first** one that describes the change's main purpose — not just "what files changed":

| Verb | When to use |
|---|---|
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

Make is the catch-all last row, so every change has a table verb — never use an off-table verb.

## Commit Workflow

1. Run `git remote get-url origin` and resolve the scope (see Scope). If it is not the user's own repo, derive the convention before drafting anything.
2. Run `git status` and `git diff` to understand all changes
3. Group related changes into logical units — each commit should represent one coherent purpose
4. Present the commit plan to the user for review before executing:
   - State which convention is in effect and why (`joresserwe/dotfiles → 개인 규칙` / `acme/api → 레포 규칙`)
   - List each proposed commit with its message and included files
   - **Annotate each proposed message inline.** Own repos: `verb → table row text` (e.g., `Move → "Only relocating code or files"`). Other repos: the observed convention and its evidence. Presenting messages without this annotation violates the skill.
   - Flag anything unusual (debug code, unintended changes, sensitive files)
5. After approval, execute commits in order

## Writing Style

Applies to the user's own repositories, except the last bullet, which always applies.

- English only, concise — aim for under 72 characters
- Lead with the verb, describe the "what" and optionally the "why" if not obvious
- Specific over vague: "Fix bufferline background color" not "Fix UI issue"
- When multiple things change in one commit, summarize the theme: "Set colorscheme to tokyonight and remove unused files"
- When describing the commit plan to the user, use Korean for explanations

## Gotchas

- **NEVER** add `Co-Authored-By` trailers or any attribution lines to commit messages. GitHub parses these as contributors, polluting the repo's contributor list.
- When rewriting git history (message edits, author changes, etc.), use `git filter-repo`.
- The inline annotation (see Workflow step 4) is the verification mechanism. Skipping the annotation means skipping the check — both violate the skill.
- Deciding scope from the directory name or from memory of a past session is not enough — run `git remote get-url origin` every time. A repo can be moved, forked, or transferred between sessions.
