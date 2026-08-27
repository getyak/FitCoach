# FitCoach

Use `README.md` and `docs/MVP_ACCEPTANCE.md` as the product contract.
`project.yml` is the source of truth for generated Xcode project settings.

## Code Review Rules

- Flag any session or credit-ledger path that can deduct a lesson before a
  successful save, deduct it more than once, or deduct for a planned, paused,
  cancelled, or zero-completion session.
- Flag SwiftData schema, import, backup, or restore changes that lack an exact
  legacy-store migration case plus idempotent duplicate-import and round-trip
  evidence for sessions, sets, measurements, and credit transactions.
- Flag rest-timer or Live Activity changes that can outlive cancel, undo, skip,
  or completion, race a later user action, block the main actor, or expose a
  client's identity or workout details outside the app.
