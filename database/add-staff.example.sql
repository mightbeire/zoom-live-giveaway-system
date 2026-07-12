-- Replace the example values before running this query.
-- Add every creator-team member who may join the Zoom call.

insert into public.staff (
  meeting_id,
  full_name,
  email,
  zoom_user_id,
  zoom_registrant_id,
  role,
  active
)
values
  ('YOUR_MEETING_ID', 'Creator / Host', 'creator@example.com', null, null, 'host', true),
  ('YOUR_MEETING_ID', 'Community Moderator', 'moderator@example.com', null, null, 'moderator', true),
  ('YOUR_MEETING_ID', 'Stream Producer', 'producer@example.com', null, null, 'producer', true);

-- The safest staff record includes as many identifiers as the team can provide:
-- email, Zoom user ID, and Zoom registrant ID.
