-- K-Beauty MEETS 2026 — Supabase Schema
-- Run this in your Supabase SQL Editor

-- 1. Registrations table (from register form)
create table if not exists registrations (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  full_name text not null,
  phone text not null,
  email text not null,
  cme_number text,
  hospital text not null,
  city text not null,
  specialty text not null,
  years_experience text not null,
  topics text[] default '{}',
  goals text,
  event text not null check (event in ('summit', 'congress', 'kat')),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'attended', 'noshow', 'cancelled')),
  checked_in_at timestamptz,
  checked_in_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. Auto-generate registration code
create or replace function generate_registration_code()
returns trigger as $$
declare
  prefix text;
  seq int;
begin
  prefix := case new.event
    when 'summit' then 'KBM-2026-S-'
    when 'congress' then 'KBM-2026-C-'
    when 'kat' then 'KBM-2026-K-'
  end;
  select coalesce(max(
    substring(code from '\d+$')::int
  ), 0) + 1 into seq
  from registrations
  where event = new.event;
  new.code := prefix || lpad(seq::text, 4, '0');
  return new;
end;
$$ language plpgsql;

create trigger set_registration_code
  before insert on registrations
  for each row
  when (new.code is null or new.code = '')
  execute function generate_registration_code();

-- 3. Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_updated_at
  before update on registrations
  for each row
  execute function update_updated_at();

-- 4. Row Level Security
alter table registrations enable row level security;

-- Public can insert (register)
create policy "Anyone can register"
  on registrations for insert
  to anon
  with check (true);

-- Only authenticated users (admin) can read
create policy "Admins can read all"
  on registrations for select
  to authenticated
  using (true);

-- Only authenticated users can update (check-in, approve)
create policy "Admins can update"
  on registrations for update
  to authenticated
  using (true)
  with check (true);

-- Public can check seat availability (count only, via RPC)
create or replace function get_event_stats(event_filter text default null)
returns json as $$
  select json_build_object(
    'total', count(*),
    'confirmed', count(*) filter (where status = 'confirmed'),
    'attended', count(*) filter (where status = 'attended'),
    'pending', count(*) filter (where status = 'pending')
  )
  from registrations
  where (event_filter is null or event = event_filter);
$$ language sql security definer;

-- 5. Indexes
create index idx_registrations_event on registrations(event);
create index idx_registrations_status on registrations(status);
create index idx_registrations_code on registrations(code);
create index idx_registrations_email on registrations(email);

-- 6. Enable realtime
alter publication supabase_realtime add table registrations;
