# Supabase Cost Budget

No live quota or dashboard measurement was performed during this repository audit. The following are planning assumptions, not observed capacity:

- cache conversation history locally and use cursor pagination;
- subscribe only to active conversations;
- debounce typing/presence and avoid heartbeat writes;
- upload media directly to private Storage with bounded size/type checks;
- keep retries bounded and idempotent;
- clean abandoned upload state with a scheduled server workflow;
- monitor database size, Storage, egress, realtime events/connections, auth abuse, and Edge Function invocations.

Subscription upgrades should normally require configuration and operational changes rather than a Flutter rewrite. Actual limits must be checked against current official Supabase plan documentation and the project dashboard before launch.

