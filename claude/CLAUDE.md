# Gotchas

- No useless comments — when adding and removing alike. A comment must earn its place by explaining something non-obvious about code that exists (e.g. a workaround's reason). A "we removed / no longer do X" note about absent code gives the reader nothing; that story goes in the commit message. When a comment does carry real value, keep it.
  - No justification comments either: anything defending the change ("this is safe because…", "not X, only Y") is reviewer-talk — commit message, not code.
  - Density check FIRST, and it is a hard gate: if the sibling lines carry no comments, yours doesn't either. "But this fact is non-obvious" does not override it — every violation so far walked in through exactly that rationalization.
  - If you find yourself weighing whether a comment earns its place, it doesn't. Default no; the rationale goes in the commit message.
