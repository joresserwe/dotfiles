---
name: skill-commit
description: Git commit message convention and commit workflow. Use this skill whenever the user asks to commit, write commit messages, or review staged changes for committing. Also trigger when the user says /commit, "commit this", "make a commit", or any variation of requesting a git commit.
---

# Git Commit Skill

## Commit Message Format

Write commit messages as a **single line** starting with an **imperative English verb** (capitalized), followed by a concise summary. No conventional commit prefixes (`feat:`, `fix:`, etc.). No message body unless explicitly requested.

**Example:**
```
Update rainbow-delimiters settings to prevent highlighting of HTML tags in React
Add manage=off rule to yabairc
Fix LSP config of TypeScript
Make 's' key toggleable in which-key settings
Set colorscheme to tokyonight and remove unused files
```

## Verb Selection

Choose the verb that best describes the **nature** of the change, not just "what files changed":

| Verb | When to use |
|---|---|
| Add | New code, tests, examples, documents |
| Implement | Significant new functionality (class, module, feature) |
| Remove | Deleting unnecessary code or files |
| Use | Switching to a specific tool, library, or approach |
| Simplify | Reducing complexity in existing code |
| Fix | Correcting broken or incorrect behavior |
| Refactor | Restructuring code without changing behavior |
| Make | Changing existing behavior |
| Allow | Enabling a feature or capability |
| Improve | Performance, compatibility, accessibility enhancements |
| Update | Version bumps, dependency updates, resource revisions |
| Correct | Typos, naming, grammatical fixes |
| Ensure | Guaranteeing a certain behavior or state |
| Prevent | Blocking undesired actions or behaviors |
| Avoid | Circumventing or working around issues |
| Move | Relocating code within the project |
| Rename | Changing names of variables, files, functions |
| Verify | Adding validation or condition checks |
| Set | Minor value changes (config values, flags) |
| Pass | Parameter or argument handling changes |

If none of these fit precisely, pick the closest one or use another imperative verb that reads naturally.

## Commit Workflow

1. Run `git status` and `git diff` to understand all changes
2. Group related changes into logical units — each commit should represent one coherent purpose
3. Present the commit plan to the user for review before executing:
   - List each proposed commit with its message and included files
   - Flag anything unusual (debug code, unintended changes, sensitive files)
4. After approval, execute commits in order

## Writing Style

- English only, concise — aim for under 72 characters
- Lead with the verb, describe the "what" and optionally the "why" if not obvious
- Specific over vague: "Fix bufferline background color" not "Fix UI issue"
- When multiple things change in one commit, summarize the theme: "Set colorscheme to tokyonight and remove unused files"
- When describing the commit plan to the user, use Korean for explanations

## Gotchas

- **NEVER** add `Co-Authored-By` trailers or any attribution lines to commit messages. GitHub parses these as contributors, polluting the repo's contributor list.
- When rewriting git history (message edits, author changes, etc.), use `git filter-repo`.
