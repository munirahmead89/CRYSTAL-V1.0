-- Crystal Messenger - create_group RPC
--
-- Creates a group chat (WhatsApp-style): creator becomes owner, all member
-- ids are added as participants, and mutual contacts are auto-created so the
-- group shows up in the contact list.  Returns a jsonb object so the Flutter
-- client can read `chat_id` from the RPC result.

CREATE OR REPLACE FUNCTION public.create_group(
  p_name TEXT,
  p_member_ids UUID[],
  p_avatar_reference TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  new_chat UUID;
  uid UUID;
BEGIN
  PERFORM public.assert_not_suspended();

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Group name is required';
  END IF;

  -- Create the group chat.
  INSERT INTO chats (type, name, avatar_url, created_by)
  VALUES ('group', btrim(p_name), p_avatar_reference, auth.uid())
  RETURNING id INTO new_chat;

  -- Creator is the owner.
  INSERT INTO chat_participants (chat_id, user_id, role)
  VALUES (new_chat, auth.uid(), 'owner');

  -- Add each member (skip self and unknown ids).
  FOREACH uid IN ARRAY p_member_ids LOOP
    CONTINUE WHEN uid = auth.uid();
    INSERT INTO chat_participants (chat_id, user_id, role)
    SELECT new_chat, uid, 'member'
    WHERE EXISTS (SELECT 1 FROM profiles p WHERE p.id = uid)
    ON CONFLICT (chat_id, user_id) DO NOTHING;
  END LOOP;

  -- Auto-create mutual contacts between creator and every member (only for
  -- accepted participants; skips silently if already present).
  FOREACH uid IN ARRAY p_member_ids LOOP
    CONTINUE WHEN uid = auth.uid();
    PERFORM public.ensure_contact_for(auth.uid(), uid);
    PERFORM public.ensure_contact_for(uid, auth.uid());
  END LOOP;

  RETURN jsonb_build_object('chat_id', new_chat, 'id', new_chat);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.create_group(TEXT, UUID[], TEXT) TO authenticated;