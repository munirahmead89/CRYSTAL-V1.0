# Database Schema Contract

The repository currently contains a broad relay migration plus a feature-contract migration. Treat `00031_full_whatsapp_relay.sql` as legacy baseline and add reviewed migrations after inspecting the target environment.

Core entities are profiles, user settings, conversations, conversation members, messages, message receipts, blocks, devices, attachments/media uploads, and optional call metadata. All client-facing tables must have RLS enabled and explicit grants/policies.

Required invariants:

- profile ID references `auth.users(id)`;
- conversation membership is unique per `(conversation_id, user_id)`;
- messages are readable only by members;
- sender identity is derived/validated from `auth.uid()`;
- sender/client idempotency keys are unique;
- receipts are unique per message and recipient;
- direct conversation creation is atomic and block-aware;
- private media paths do not grant access by path alone.

Use keyset pagination ordered by `(created_at, id)` and select only fields required by the screen.

