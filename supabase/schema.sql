-- =============================================================================
-- CampusConnect AUS — Supabase Postgres Schema
-- Project: campus-connect-aus
-- Run this in: Supabase Dashboard → SQL Editor → New Query → Run
-- =============================================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- =============================================================================
-- CLEANUP: Drop existing objects (idempotent — safe to re-run)
-- =============================================================================
drop function if exists public.reset_unread_count cascade;
drop function if exists public.increment_unread_and_update_preview cascade;
drop table if exists public.sos_alerts cascade;
drop table if exists public.listings cascade;
drop table if exists public.chat_members cascade;
drop table if exists public.typing_indicators cascade;
drop table if exists public.messages cascade;
drop table if exists public.chats cascade;
drop table if exists public.users cascade;

-- =============================================================================
-- USERS TABLE
-- Mirrors the auth.users table with extra profile fields.
-- =============================================================================
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  email       text not null,
  role        text not null default 'student' check (role in ('student', 'admin')),
  matric_number text,
  photo_url   text,
  created_at  timestamptz not null default now()
);

alter table public.users enable row level security;

-- Users can read their own profile
create policy "users: read own" on public.users
  for select using (auth.uid() = id);

-- Users can update their own profile
create policy "users: update own" on public.users
  for update using (auth.uid() = id);

-- Users can insert their own profile (on register)
create policy "users: insert own" on public.users
  for insert with check (auth.uid() = id);

-- =============================================================================
-- CHATS TABLE
-- =============================================================================
create table if not exists public.chats (
  id                      uuid primary key default gen_random_uuid(),
  participants            uuid[] not null,
  last_message_text       text default '',
  last_message_sender_id  uuid,
  last_message_time       timestamptz default now(),
  updated_at              timestamptz default now(),
  unread_counts           jsonb not null default '{}'::jsonb
);

alter table public.chats enable row level security;

-- Users can only see chats they participate in
create policy "chats: read own" on public.chats
  for select using (auth.uid() = any(participants));

create policy "chats: update own" on public.chats
  for update using (auth.uid() = any(participants));

create policy "chats: insert" on public.chats
  for insert with check (auth.uid() = any(participants));

-- Index for fast participant lookup
create index if not exists chats_participants_idx on public.chats using gin(participants);

-- =============================================================================
-- MESSAGES TABLE
-- =============================================================================
create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  chat_id     uuid not null references public.chats(id) on delete cascade,
  sender_id   uuid not null references auth.users(id),
  sender_name text not null default '',
  content     text not null,
  status      text not null default 'sent' check (status in ('sending', 'sent', 'delivered', 'read')),
  created_at  timestamptz not null default now(),
  edited_at   timestamptz
);

alter table public.messages enable row level security;

-- Users can read messages in their chats
create policy "messages: read" on public.messages
  for select using (
    exists (
      select 1 from public.chats
      where id = messages.chat_id
        and auth.uid() = any(participants)
    )
  );

create policy "messages: insert" on public.messages
  for insert with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.chats
      where id = chat_id
        and auth.uid() = any(participants)
    )
  );

create policy "messages: update own" on public.messages
  for update using (auth.uid() = sender_id);

create index if not exists messages_chat_id_idx on public.messages(chat_id);
create index if not exists messages_created_at_idx on public.messages(created_at);

-- =============================================================================
-- TYPING INDICATORS TABLE
-- =============================================================================
create table if not exists public.typing_indicators (
  chat_id     uuid not null references public.chats(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  is_typing   boolean not null default false,
  updated_at  timestamptz not null default now(),
  primary key (chat_id, user_id)
);

alter table public.typing_indicators enable row level security;

create policy "typing: read" on public.typing_indicators
  for select using (
    exists (
      select 1 from public.chats
      where id = typing_indicators.chat_id
        and auth.uid() = any(participants)
    )
  );

create policy "typing: upsert" on public.typing_indicators
  for all using (auth.uid() = user_id);

-- =============================================================================
-- CHAT MEMBERS TABLE
-- =============================================================================
create table if not exists public.chat_members (
  chat_id     uuid not null references public.chats(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz default now(),
  primary key (chat_id, user_id)
);

alter table public.chat_members enable row level security;

create policy "chat_members: read own" on public.chat_members
  for select using (auth.uid() = user_id);

create policy "chat_members: upsert own" on public.chat_members
  for all using (auth.uid() = user_id);

-- =============================================================================
-- LISTINGS TABLE (Marketplace)
-- =============================================================================
create table if not exists public.listings (
  id          uuid primary key default gen_random_uuid(),
  seller_id   uuid not null references auth.users(id),
  title       text not null,
  description text not null default '',
  category    text not null default 'other'
                check (category in ('books', 'electronics', 'clothing', 'services', 'other')),
  cost        numeric(10,2) not null default 0 check (cost >= 0),
  image_url   text,
  status      text not null default 'active'
                check (status in ('active', 'pending', 'sold', 'cancelled')),
  is_flagged  boolean not null default false,
  buyer_id    uuid references auth.users(id),
  verified_at timestamptz,
  created_at  timestamptz not null default now()
);

alter table public.listings enable row level security;

-- Anyone authenticated can view active, unflagged listings
create policy "listings: read active" on public.listings
  for select using (
    auth.uid() is not null
    and (status = 'active' and not is_flagged
      or seller_id = auth.uid()
      or buyer_id = auth.uid())
  );

create policy "listings: insert own" on public.listings
  for insert with check (auth.uid() = seller_id);

create policy "listings: update own" on public.listings
  for update using (auth.uid() = seller_id or auth.uid() = buyer_id);

create policy "listings: delete own" on public.listings
  for delete using (auth.uid() = seller_id);

create index if not exists listings_seller_idx on public.listings(seller_id);
create index if not exists listings_status_idx on public.listings(status);

-- =============================================================================
-- SOS ALERTS TABLE
-- =============================================================================
create table if not exists public.sos_alerts (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references auth.users(id),
  sender_name text not null default '',
  latitude    double precision not null,
  longitude   double precision not null,
  status      text not null default 'active' check (status in ('active', 'resolved')),
  created_at  timestamptz not null default now()
);

alter table public.sos_alerts enable row level security;

-- All authenticated users can read active alerts (campus safety)
create policy "sos: read active" on public.sos_alerts
  for select using (auth.uid() is not null);

-- Any authenticated user can trigger an alert
create policy "sos: insert" on public.sos_alerts
  for insert with check (auth.uid() = sender_id);

-- Only the sender or admins can resolve
create policy "sos: update own" on public.sos_alerts
  for update using (auth.uid() = sender_id);

create index if not exists sos_status_idx on public.sos_alerts(status);

-- =============================================================================
-- RPC: increment_unread_and_update_preview
-- Called by SupabaseChatRepository.sendMessage
-- =============================================================================
create or replace function increment_unread_and_update_preview(
  p_chat_id  uuid,
  p_sender_id uuid,
  p_content  text,
  p_sent_at  timestamptz
) returns void
language plpgsql security definer as $$
declare
  v_participants uuid[];
  v_unread_counts jsonb;
  v_pid uuid;
begin
  select participants, unread_counts
    into v_participants, v_unread_counts
    from public.chats
   where id = p_chat_id;

  -- Increment unread count for every participant except the sender
  foreach v_pid in array v_participants loop
    if v_pid <> p_sender_id then
      v_unread_counts := jsonb_set(
        v_unread_counts,
        array[v_pid::text],
        to_jsonb(coalesce((v_unread_counts ->> v_pid::text)::int, 0) + 1)
      );
    end if;
  end loop;

  update public.chats set
    last_message_text      = p_content,
    last_message_sender_id = p_sender_id,
    last_message_time      = p_sent_at,
    updated_at             = now(),
    unread_counts          = v_unread_counts
  where id = p_chat_id;
end;
$$;

-- =============================================================================
-- RPC: reset_unread_count
-- Called by SupabaseChatRepository.markAsRead
-- =============================================================================
create or replace function reset_unread_count(
  p_chat_id uuid,
  p_user_id uuid
) returns void
language plpgsql security definer as $$
begin
  update public.chats set
    unread_counts = jsonb_set(
      unread_counts,
      array[p_user_id::text],
      '0'::jsonb
    )
  where id = p_chat_id;
end;
$$;

-- =============================================================================
-- Enable Realtime for relevant tables
-- Run these in the Supabase Dashboard → Database → Replication
-- (or via the API — listed here for reference)
-- =============================================================================
-- alter publication supabase_realtime add table public.chats;
-- alter publication supabase_realtime add table public.messages;
-- alter publication supabase_realtime add table public.typing_indicators;
-- alter publication supabase_realtime add table public.listings;
-- alter publication supabase_realtime add table public.sos_alerts;
