create extension if not exists pgcrypto;

create table if not exists public.meeting_counters (
  meeting_id text primary key,
  last_serial bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.entrants (
  id uuid primary key default gen_random_uuid(),
  meeting_id text not null,
  serial_no bigint not null,
  full_name text not null,
  email text not null,
  zoom_registrant_id text,
  join_url text,
  source text not null default 'registration-webhook',
  disqualified boolean not null default false,
  disqualification_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (meeting_id, email),
  unique (meeting_id, serial_no),
  unique (meeting_id, zoom_registrant_id)
);
create index if not exists entrants_meeting_email_idx on public.entrants(meeting_id, lower(email));

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  meeting_id text not null,
  full_name text not null,
  email text,
  zoom_user_id text,
  zoom_registrant_id text,
  role text not null default 'team',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists staff_meeting_email_unique on public.staff(meeting_id, lower(email)) where email is not null;

create table if not exists public.zoom_events (
  id bigint generated always as identity primary key,
  event_key text not null unique,
  event_type text not null,
  meeting_id text not null,
  meeting_uuid text not null,
  participant_uuid text not null,
  event_time timestamptz not null,
  raw_payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.participant_sessions (
  meeting_uuid text not null,
  participant_uuid text not null,
  meeting_id text not null,
  entrant_id uuid references public.entrants(id) on delete set null,
  registrant_id text,
  zoom_user_id text,
  email text,
  participant_name text not null,
  is_staff boolean not null default false,
  active boolean not null default false,
  joined_at timestamptz,
  left_at timestamptz,
  last_event_at timestamptz not null,
  primary key(meeting_uuid, participant_uuid)
);
create index if not exists participant_sessions_live_idx on public.participant_sessions(meeting_uuid, active, entrant_id, is_staff);

create table if not exists public.giveaway_locks (
  id uuid primary key default gen_random_uuid(),
  meeting_id text not null,
  meeting_uuid text not null unique,
  requested_by text,
  locked_at timestamptz not null default now(),
  eligible_count integer not null default 0,
  immutable boolean not null default true,
  sheet_id text,
  sheet_title text,
  sheet_url text
);

create table if not exists public.giveaway_lock_entries (
  lock_id uuid not null references public.giveaway_locks(id) on delete restrict,
  draw_number integer not null,
  entrant_id uuid not null references public.entrants(id) on delete restrict,
  serial_no bigint not null,
  full_name text not null,
  masked_email text not null,
  present_at timestamptz not null,
  primary key(lock_id, draw_number),
  unique(lock_id, entrant_id)
);

create table if not exists public.app_secrets (
  secret_key text primary key,
  secret_value text not null,
  updated_at timestamptz not null default now()
);

create or replace function public.mask_email(p_email text)
returns text language sql immutable as $$
  select case when p_email is null or position('@' in p_email)=0 then 'hidden'
  else left(split_part(p_email,'@',1),2)
    || repeat('*', greatest(length(split_part(p_email,'@',1))-2,2))
    || '@' || split_part(p_email,'@',2) end;
$$;

create or replace function public.api_save_secret(p jsonb)
returns jsonb language plpgsql as $$
begin
  if coalesce(p->>'secretValue','') in ('','PASTE_ZOOM_WEBHOOK_SECRET_HERE') then
    return jsonb_build_object('ok',false,'error','Paste the real Zoom webhook secret before running this setup branch.');
  end if;
  insert into public.app_secrets(secret_key,secret_value,updated_at)
  values(coalesce(nullif(p->>'secretKey',''),'zoom_webhook_secret'),p->>'secretValue',now())
  on conflict(secret_key) do update set secret_value=excluded.secret_value,updated_at=now();
  return jsonb_build_object('ok',true,'saved',true,'secretKey',coalesce(nullif(p->>'secretKey',''),'zoom_webhook_secret'));
end; $$;

create or replace function public.api_find_entrant(p jsonb)
returns jsonb language sql stable as $$
  select coalesce((select to_jsonb(e) from public.entrants e
    where e.meeting_id=p->>'meetingId' and lower(e.email)=lower(trim(p->>'email')) limit 1),'{}'::jsonb);
$$;

create or replace function public.api_register_entrant(p jsonb)
returns jsonb language plpgsql as $$
declare v_row public.entrants%rowtype; v_serial bigint;
begin
  select * into v_row from public.entrants
   where meeting_id=p->>'meetingId' and lower(email)=lower(trim(p->>'email')) limit 1;
  if found then return to_jsonb(v_row); end if;

  insert into public.meeting_counters(meeting_id,last_serial)
  values(p->>'meetingId',1)
  on conflict(meeting_id) do update set last_serial=public.meeting_counters.last_serial+1,updated_at=now()
  returning last_serial into v_serial;

  insert into public.entrants(meeting_id,serial_no,full_name,email,zoom_registrant_id,join_url,source)
  values(p->>'meetingId',v_serial,trim(p->>'fullName'),lower(trim(p->>'email')),
         nullif(p->>'zoomRegistrantId',''),p->>'joinUrl',coalesce(nullif(p->>'source',''),'registration-webhook'))
  returning * into v_row;
  return to_jsonb(v_row);
exception when unique_violation then
  select * into v_row from public.entrants
   where meeting_id=p->>'meetingId' and lower(email)=lower(trim(p->>'email')) limit 1;
  return to_jsonb(v_row);
end; $$;

create or replace function public.api_process_zoom_event(p jsonb)
returns jsonb language plpgsql as $$
declare
  v_inserted integer; v_entrant_id uuid; v_is_staff boolean:=false; v_active_sessions integer:=0;
  v_join boolean := (p->>'eventType'='meeting.participant_joined');
  v_time timestamptz := (p->>'eventTime')::timestamptz;
begin
  insert into public.zoom_events(event_key,event_type,meeting_id,meeting_uuid,participant_uuid,event_time,raw_payload)
  values(p->>'eventKey',p->>'eventType',p->>'meetingId',p->>'meetingUuid',p->>'participantUuid',v_time,coalesce(p->'rawPayload','{}'::jsonb))
  on conflict(event_key) do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then return jsonb_build_object('ok',true,'duplicate',true); end if;

  select e.id into v_entrant_id from public.entrants e
   where e.meeting_id=p->>'meetingId' and (
     (nullif(p->>'registrantId','') is not null and e.zoom_registrant_id=p->>'registrantId') or
     (nullif(p->>'email','') is not null and lower(e.email)=lower(p->>'email')))
   order by case when e.zoom_registrant_id=p->>'registrantId' then 0 else 1 end limit 1;

  select exists(select 1 from public.staff s where s.meeting_id=p->>'meetingId' and s.active and (
      (nullif(p->>'email','') is not null and s.email is not null and lower(s.email)=lower(p->>'email')) or
      (nullif(p->>'zoomUserId','') is not null and s.zoom_user_id=p->>'zoomUserId') or
      (nullif(p->>'registrantId','') is not null and s.zoom_registrant_id=p->>'registrantId'))) into v_is_staff;

  insert into public.participant_sessions(meeting_uuid,participant_uuid,meeting_id,entrant_id,registrant_id,zoom_user_id,email,participant_name,is_staff,active,joined_at,left_at,last_event_at)
  values(p->>'meetingUuid',p->>'participantUuid',p->>'meetingId',v_entrant_id,nullif(p->>'registrantId',''),nullif(p->>'zoomUserId',''),
         nullif(lower(p->>'email'),''),coalesce(nullif(trim(p->>'name'),''),'Unknown participant'),v_is_staff,v_join,
         case when v_join then v_time end,case when not v_join then v_time end,v_time)
  on conflict(meeting_uuid,participant_uuid) do update set
    meeting_id=excluded.meeting_id,
    entrant_id=coalesce(excluded.entrant_id,public.participant_sessions.entrant_id),
    registrant_id=coalesce(excluded.registrant_id,public.participant_sessions.registrant_id),
    zoom_user_id=coalesce(excluded.zoom_user_id,public.participant_sessions.zoom_user_id),
    email=coalesce(excluded.email,public.participant_sessions.email),
    participant_name=excluded.participant_name,
    is_staff=excluded.is_staff,
    active=excluded.active,
    joined_at=case when excluded.active then coalesce(public.participant_sessions.joined_at,excluded.joined_at) else public.participant_sessions.joined_at end,
    left_at=case when not excluded.active then excluded.left_at else null end,
    last_event_at=excluded.last_event_at;

  if v_entrant_id is not null then
    select count(*)::integer into v_active_sessions from public.participant_sessions
     where meeting_uuid=p->>'meetingUuid' and entrant_id=v_entrant_id and active;
  end if;
  return jsonb_build_object('ok',true,'duplicate',false,'matchedEntrant',v_entrant_id is not null,'entrantId',v_entrant_id,'isStaff',v_is_staff,'activeSessions',v_active_sessions);
end; $$;

create or replace function public.api_get_status(p jsonb)
returns jsonb language plpgsql stable as $$
declare v_uuid text; v_lock public.giveaway_locks%rowtype;
begin
  v_uuid:=coalesce(nullif(p->>'meetingUuid',''),(select ps.meeting_uuid from public.participant_sessions ps where ps.meeting_id=p->>'meetingId' order by ps.last_event_at desc limit 1));
  select * into v_lock from public.giveaway_locks where meeting_uuid=v_uuid limit 1;
  return jsonb_build_object(
   'ok',true,'meetingId',p->>'meetingId','meetingUuid',v_uuid,
   'registered',(select count(*) from public.entrants e where e.meeting_id=p->>'meetingId'),
   'connectedSessions',(select count(*) from public.participant_sessions ps where ps.meeting_uuid=v_uuid and ps.active),
   'identifiedEntrants',(select count(distinct ps.entrant_id) from public.participant_sessions ps where ps.meeting_uuid=v_uuid and ps.active and ps.entrant_id is not null and not ps.is_staff),
   'staffConnected',(select count(distinct ps.participant_uuid) from public.participant_sessions ps where ps.meeting_uuid=v_uuid and ps.active and ps.is_staff),
   'unmatchedParticipants',(select count(distinct ps.participant_uuid) from public.participant_sessions ps where ps.meeting_uuid=v_uuid and ps.active and ps.entrant_id is null and not ps.is_staff),
   'currentlyEligible',(select count(distinct e.id) from public.entrants e where e.meeting_id=p->>'meetingId' and not e.disqualified
       and exists(select 1 from public.participant_sessions ps where ps.meeting_uuid=v_uuid and ps.entrant_id=e.id and ps.active and not ps.is_staff)
       and not exists(select 1 from public.staff s where s.meeting_id=p->>'meetingId' and s.active and ((s.email is not null and lower(s.email)=lower(e.email)) or (s.zoom_registrant_id is not null and s.zoom_registrant_id=e.zoom_registrant_id)))),
   'locked',v_lock.id is not null,'lockId',v_lock.id,'lockedAt',v_lock.locked_at,'eligibleCount',coalesce(v_lock.eligible_count,0),'sheetUrl',v_lock.sheet_url);
end; $$;

create or replace function public.api_lock_giveaway(p jsonb)
returns jsonb language plpgsql as $$
declare v_lock public.giveaway_locks%rowtype; v_count integer; v_entries jsonb; v_existing boolean:=false;
begin
  if coalesce(p->>'meetingId','')='' or coalesce(p->>'meetingUuid','')='' then
    return jsonb_build_object('ok',false,'error','meetingId and meetingUuid are required.');
  end if;
  perform pg_advisory_xact_lock(hashtext(p->>'meetingUuid'));
  select * into v_lock from public.giveaway_locks where meeting_uuid=p->>'meetingUuid' limit 1;
  if found then v_existing:=true;
  else
    insert into public.giveaway_locks(meeting_id,meeting_uuid,requested_by)
    values(p->>'meetingId',p->>'meetingUuid',coalesce(nullif(p->>'requestedBy',''),'creator-dashboard')) returning * into v_lock;

    with eligible as (
      select e.id entrant_id,e.serial_no,e.full_name,public.mask_email(e.email) masked_email,max(ps.last_event_at) present_at
      from public.entrants e join public.participant_sessions ps on ps.entrant_id=e.id and ps.meeting_uuid=p->>'meetingUuid' and ps.active and not ps.is_staff
      where e.meeting_id=p->>'meetingId' and not e.disqualified
       and not exists(select 1 from public.staff s where s.meeting_id=p->>'meetingId' and s.active and ((s.email is not null and lower(s.email)=lower(e.email)) or (s.zoom_registrant_id is not null and s.zoom_registrant_id=e.zoom_registrant_id)))
      group by e.id,e.serial_no,e.full_name,e.email
    ), numbered as (
      select row_number() over(order by serial_no)::integer draw_number,* from eligible
    )
    insert into public.giveaway_lock_entries(lock_id,draw_number,entrant_id,serial_no,full_name,masked_email,present_at)
    select v_lock.id,draw_number,entrant_id,serial_no,full_name,masked_email,present_at from numbered;

    select count(*)::integer into v_count from public.giveaway_lock_entries where lock_id=v_lock.id;
    if v_count=0 then
      delete from public.giveaway_locks where id=v_lock.id;
      return jsonb_build_object('ok',false,'error','No eligible registered attendees are currently present.');
    end if;
    update public.giveaway_locks set eligible_count=v_count where id=v_lock.id returning * into v_lock;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('drawNumber',le.draw_number,'serialNo',le.serial_no,'fullName',le.full_name,'maskedEmail',le.masked_email,'presentAt',le.present_at) order by le.draw_number),'[]'::jsonb)
  into v_entries from public.giveaway_lock_entries le where le.lock_id=v_lock.id;
  return jsonb_build_object('ok',true,'lockId',v_lock.id,'alreadyLocked',v_existing,'meetingId',v_lock.meeting_id,'meetingUuid',v_lock.meeting_uuid,
    'lockedAt',v_lock.locked_at,'eligibleCount',v_lock.eligible_count,'sheetId',v_lock.sheet_id,'sheetTitle',v_lock.sheet_title,'sheetUrl',v_lock.sheet_url,'entries',v_entries);
end; $$;

create or replace function public.api_attach_sheet(p jsonb)
returns jsonb language plpgsql as $$
declare v_lock public.giveaway_locks%rowtype;
begin
  update public.giveaway_locks set sheet_id=coalesce(sheet_id,p->>'sheetId'),sheet_title=coalesce(sheet_title,p->>'sheetTitle'),sheet_url=coalesce(sheet_url,p->>'sheetUrl')
  where id=(p->>'lockId')::uuid returning * into v_lock;
  if v_lock.id is null then return jsonb_build_object('ok',false,'error','Giveaway lock not found.'); end if;
  return jsonb_build_object('ok',true,'lockId',v_lock.id,'eligibleCount',v_lock.eligible_count,'lockedAt',v_lock.locked_at,'sheetId',v_lock.sheet_id,'sheetTitle',v_lock.sheet_title,'sheetUrl',v_lock.sheet_url);
end; $$;

create or replace function public.api_seed_demo(p jsonb)
returns jsonb language plpgsql as $$
declare v_meeting text:=coalesce(nullif(p->>'meetingId',''),'DEMO-MEETING-001'); v_uuid text:=coalesce(nullif(p->>'meetingUuid',''),'demo-live-001'); i integer;
begin
  delete from public.giveaway_lock_entries where lock_id in (select id from public.giveaway_locks where meeting_uuid=v_uuid);
  delete from public.giveaway_locks where meeting_uuid=v_uuid;
  delete from public.participant_sessions where meeting_uuid=v_uuid;
  delete from public.zoom_events where meeting_uuid=v_uuid;
  delete from public.entrants where meeting_id=v_meeting;
  delete from public.staff where meeting_id=v_meeting;
  delete from public.meeting_counters where meeting_id=v_meeting;
  for i in 1..25 loop
    insert into public.entrants(meeting_id,serial_no,full_name,email,zoom_registrant_id,join_url,source)
    values(v_meeting,i,'Demo Entrant '||lpad(i::text,2,'0'),'entrant'||lpad(i::text,2,'0')||'@example.com','demo-registrant-'||lpad(i::text,2,'0'),
      'https://zoom.example.invalid/j/'||v_meeting||'?tk=demo-'||lpad(i::text,2,'0'),'demo-seed');
  end loop;
  insert into public.meeting_counters(meeting_id,last_serial) values(v_meeting,25);
  insert into public.staff(meeting_id,full_name,email,zoom_user_id,role) values
    (v_meeting,'Creator / Host','creator@example.com','zoom-host-001','host'),
    (v_meeting,'Community Moderator','moderator@example.com','zoom-mod-001','moderator'),
    (v_meeting,'Stream Producer','producer@example.com','zoom-producer-001','producer');
  return jsonb_build_object('ok',true,'meetingId',v_meeting,'meetingUuid',v_uuid,'entrants',25,'staff',3);
end; $$;

create or replace function public.api_demo_attendance(p jsonb)
returns jsonb language plpgsql as $$
declare v_meeting text:=coalesce(nullif(p->>'meetingId',''),'DEMO-MEETING-001'); v_uuid text:=coalesce(nullif(p->>'meetingUuid',''),'demo-live-001'); v_action text:=p->>'action';
begin
  if v_action='reset' then
    delete from public.participant_sessions where meeting_uuid=v_uuid;
  elsif v_action='join_entrants' then
    insert into public.participant_sessions(meeting_uuid,participant_uuid,meeting_id,entrant_id,registrant_id,email,participant_name,is_staff,active,joined_at,last_event_at)
    select v_uuid,'demo-entrant-'||lpad(e.serial_no::text,2,'0'),v_meeting,e.id,e.zoom_registrant_id,e.email,e.full_name,false,true,now(),now()
    from public.entrants e where e.meeting_id=v_meeting
    on conflict(meeting_uuid,participant_uuid) do update set active=true,left_at=null,last_event_at=now();
  elsif v_action='join_staff' then
    insert into public.participant_sessions(meeting_uuid,participant_uuid,meeting_id,zoom_user_id,email,participant_name,is_staff,active,joined_at,last_event_at)
    select v_uuid,'demo-staff-'||row_number() over(order by s.role),v_meeting,s.zoom_user_id,s.email,s.full_name,true,true,now(),now()
    from public.staff s where s.meeting_id=v_meeting and s.active
    on conflict(meeting_uuid,participant_uuid) do update set active=true,left_at=null,last_event_at=now();
  elsif v_action='leave_five' then
    update public.participant_sessions ps set active=false,left_at=now(),last_event_at=now()
    from public.entrants e where ps.meeting_uuid=v_uuid and ps.entrant_id=e.id and e.meeting_id=v_meeting and e.serial_no>20;
  else
    return jsonb_build_object('ok',false,'error','Unknown demo action.');
  end if;
  return public.api_get_status(jsonb_build_object('meetingId',v_meeting,'meetingUuid',v_uuid));
end; $$;
