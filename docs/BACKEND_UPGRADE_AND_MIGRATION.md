# Backend Upgrade and Migration

Apply migrations in order to a disposable environment first, then staging, then production with a verified backup. Use additive, reversible changes where possible. Never drop or rewrite user data as part of routine upgrades.

A normal Supabase subscription upgrade should not require client code changes. Review quotas, connection limits, database size, Storage/egress, Edge Function limits, backups, and observability. Moving to another provider is different: it requires schema/data migration, auth identity handling, storage transfer, and replacement of adapters/configuration.

Rollback means stopping new writes only when necessary, restoring a verified backup or applying a forward-fix migration, and reconciling outbox/realtime state. Do not use destructive rollback against production without explicit approval.

## Inactive account deletion

Migration `00033_crystal_consolidated_hardening.sql` defines the 14-day inactivity contract. The protected `cleanup-expired-data` Edge Function calls the service-role Admin API to permanently delete inactive Auth users; cascading database cleanup then removes their public profile and owned records. Configure `CRON_SECRET` and invoke the function on a trusted daily schedule. Never expose the service-role key or invoke this function from Flutter.

