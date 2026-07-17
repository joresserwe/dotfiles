# Gotchas

## Comments — mechanical procedure, no judgment calls

Run this checklist on EVERY comment line you are about to add (or modify), one comment at a time, before finishing the edit. Rules are checked in order; the FIRST rule that matches decides. Do not weigh trade-offs, do not reason about whether this case is special — if a rule matches, apply it. This applies everywhere comments can appear: source files, configs, scripts, and code blocks inside plan/spec documents (those get copied verbatim later, so they must pass the same checklist when written).

**Rule 1 — change-story language → DELETE, move the sentence to the commit message.**
The comment matches if it contains any wording that only makes sense relative to the edit you are making, including (non-exhaustive, match the spirit mechanically): "added / removed / renamed / replaced / changed / moved / migrated", "now / no longer / anymore / instead of / previously / used to / before / new / old", "safe because / this is fine because / doesn't break", or any mention of why this edit was made, what it replaces, or what problem the edit fixes. The reader sees only the code after the change; the A→B story is commit-message content, always.

**Rule 2 — explaining your own edit → DELETE, move to the commit message.**
The comment matches if its content answers "why did I (Claude) do this edit" or "why is this edit correct/needed" — even without Rule 1's trigger words. Example from a real violation: on a line adding ShareX to an ignore list, writing "capture overlay is fullscreen borderless; WM management breaks the capture UX" — that is the rationale for the edit, not documentation of the code. Commit message.

**Rule 3 — echo → DELETE.**
Cover the comment and read only the code it sits on. If the comment's entire content can be reconstructed from the code itself (the names, values, and structure already say it), delete it. `window_process: ShareX` inside an ignore rule already documents "ShareX is excluded" — a comment saying so, or saying what the tool is for, adds nothing. Neighboring lines having comments does NOT change this rule's outcome; comment density of the file is never an input to any rule here.

**Rule 4 — non-obvious fact about the current code → WRITE / KEEP.**
The comment matches if it states something a reader of the current code cannot recover from the code, and needs: the reason a workaround exists, an upstream bug or issue reference, an observed failure that forces this exact shape ("X hangs when Y, hence the timeout"), a required ordering, a non-obvious unit/format/encoding. These are wanted. Write them when they apply; never skip one because of the rules above — Rules 1–3 target sentences ABOUT THE EDIT, Rule 4 targets sentences ABOUT THE CODE. The distinction is mechanical: rewrite the sentence assuming the code was always this way; if it survives unchanged and still informs, it is Rule 4.

**Rule 5 — nothing above matched → DELETE.**
The default is delete. "It might help someone" is not a rule.

**Existing comments (deletion side):** never delete a comment that passes Rule 4, and never replace deleted code with a tombstone comment ("we removed X / no longer do Y" about absent code) — absent code gets no comment at all; the removal story goes in the commit message.
