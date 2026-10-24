# Backup and Recovery

Before production migrations, verify a restorable database backup and record the migration version. Back up database data, Storage objects, deployment configuration, and required environment-variable names separately; never commit secret values.

Recovery must include auth identity continuity, database restore, Storage object validation, migration replay/verification, client session behavior, and outbox reconciliation. Test recovery in a non-production project before relying on it.

