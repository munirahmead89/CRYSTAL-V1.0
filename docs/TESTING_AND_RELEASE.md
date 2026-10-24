# Testing and Release

Local baseline commands:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Database/RLS tests require a disposable Supabase/Postgres environment with two separate anonymous test identities. Integration coverage should include session restore, profile setup, direct conversation creation, send/receive, duplicate retry, offline outbox restart, reconnect recovery, receipts, attachments, and unauthorized access.

The repository audit does not claim a live Supabase migration, push provider, calling transport, or release build has passed. Release notes must identify platform-specific support and all missing external configuration.

