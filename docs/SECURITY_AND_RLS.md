# Security and RLS

The Flutter app must contain only the Supabase publishable/anon key. Service-role keys, database passwords, push-provider credentials, and signing secrets belong in server/deployment configuration.

The current migration requires hardening before release: profile reads are broad and media chunk access includes an unconditional branch. The next migration must replace these with policies based on authenticated identity, conversation membership, uploader ownership, and message authorization.

Minimum security tests:

- a user cannot read another user's private settings;
- a non-member cannot read or write conversation messages;
- a caller cannot forge `sender_id`;
- a recipient cannot change another user's receipt;
- profiles can only be changed by their owner;
- blocks prevent prohibited discovery/conversation/message operations;
- private Storage objects require ownership or conversation authorization.

Anonymous auth is authenticated access, not proof of a unique human. Add server/provider quotas and abuse controls before public launch.

Inactive anonymous accounts are removed after 14 days without activity by a protected server-side cleanup job. Activity timestamps must be updated only by authenticated server workflows; the client cannot extend retention by submitting another user's ID.

