-- K-Beauty MEETS 2026 — Supabase Schema
-- Run this in your Supabase SQL Editor

-- ═══════════════════════════════════════════════
-- 1. EVENTS table
-- ═══════════════════════════════════════════════
create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  date_start date not null,
  date_end date,
  venue text,
  city text,
  capacity int default 0,
  description text,
  status text not null default 'upcoming' check (status in ('upcoming', 'ongoing', 'completed', 'cancelled')),
  color text default '#0B6B54',
  sort_order int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Seed default events
insert into events (name, slug, date_start, date_end, venue, city, capacity, color, sort_order, status) values
  ('KSAPS Summit 2026', 'summit', '2026-10-03', '2026-10-03', 'Kangnam Aesthetic Hospital', 'Ho Chi Minh City', 100, '#4A3FA8', 1, 'upcoming'),
  ('KAT Vietnam 2026', 'kat', '2026-10-04', '2026-10-04', 'TBD', 'Ho Chi Minh City', 150, '#C97C14', 2, 'upcoming'),
  ('KSAPS Congress 2026', 'congress', '2026-10-17', '2026-10-18', '108 Military Central Hospital', 'Hanoi', 200, '#C44B28', 3, 'upcoming')
on conflict (slug) do nothing;

-- ═══════════════════════════════════════════════
-- 2. REGISTRATIONS table (from register form)
-- ═══════════════════════════════════════════════
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
  rooms text[] default '{}',
  gala boolean default false,
  cme boolean default false,
  amount int default 0,
  currency text default 'VND',
  payment_status text default 'unpaid' check (payment_status in ('unpaid', 'paid', 'refunded')),
  notes text,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'attended', 'noshow', 'cancelled')),
  checked_in_at timestamptz,
  checked_in_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ═══════════════════════════════════════════════
-- 3. GALLERY_IMAGES table
-- ═══════════════════════════════════════════════
create table if not exists gallery_images (
  id uuid primary key default gen_random_uuid(),
  event_slug text not null,
  title text,
  description text,
  storage_path text not null,
  image_url text not null,
  display_order int default 0,
  is_featured boolean default false,
  layout text default 'normal' check (layout in ('normal', 'wide', 'tall')),
  uploaded_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create index if not exists idx_gallery_event on gallery_images(event_slug);
create index if not exists idx_gallery_order on gallery_images(event_slug, display_order);

-- ═══════════════════════════════════════════════
-- 4. AUTO-GENERATE registration code
-- ═══════════════════════════════════════════════
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

drop trigger if exists set_registration_code on registrations;
create trigger set_registration_code
  before insert on registrations
  for each row
  when (new.code is null or new.code = '')
  execute function generate_registration_code();

-- ═══════════════════════════════════════════════
-- 5. AUTO-UPDATE updated_at
-- ═══════════════════════════════════════════════
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_updated_at on registrations;
create trigger set_updated_at
  before update on registrations
  for each row
  execute function update_updated_at();

drop trigger if exists set_events_updated_at on events;
create trigger set_events_updated_at
  before update on events
  for each row
  execute function update_updated_at();

-- ═══════════════════════════════════════════════
-- 6. ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════

-- Registrations
alter table registrations enable row level security;

create policy "Anyone can register"
  on registrations for insert
  to anon
  with check (true);

create policy "Admins can read all"
  on registrations for select
  to authenticated
  using (true);

create policy "Admins can update"
  on registrations for update
  to authenticated
  using (true)
  with check (true);

create policy "Admins can delete registrations"
  on registrations for delete
  to authenticated
  using (true);

-- Events
alter table events enable row level security;

create policy "Public can read events"
  on events for select
  to anon, authenticated
  using (true);

create policy "Admins can manage events"
  on events for all
  to authenticated
  using (true)
  with check (true);

-- Gallery
alter table gallery_images enable row level security;

create policy "Public can view gallery"
  on gallery_images for select
  to anon, authenticated
  using (true);

create policy "Admins can manage gallery"
  on gallery_images for all
  to authenticated
  using (true)
  with check (true);

-- ═══════════════════════════════════════════════
-- 7. RPC FUNCTIONS
-- ═══════════════════════════════════════════════

create or replace function get_event_stats(event_filter text default null)
returns json as $$
  select json_build_object(
    'total', count(*),
    'confirmed', count(*) filter (where status = 'confirmed'),
    'attended', count(*) filter (where status = 'attended'),
    'pending', count(*) filter (where status = 'pending'),
    'cancelled', count(*) filter (where status = 'cancelled')
  )
  from registrations
  where (event_filter is null or event = event_filter);
$$ language sql security definer;

create or replace function get_dashboard_stats()
returns json as $$
  select json_build_object(
    'total', (select count(*) from registrations),
    'confirmed', (select count(*) from registrations where status = 'confirmed'),
    'attended', (select count(*) from registrations where status = 'attended'),
    'pending', (select count(*) from registrations where status = 'pending'),
    'cancelled', (select count(*) from registrations where status = 'cancelled'),
    'today_checkins', (select count(*) from registrations where checked_in_at::date = current_date),
    'events', (select json_agg(row_to_json(e)) from (
      select ev.slug, ev.name, ev.capacity, ev.color,
        (select count(*) from registrations r where r.event = ev.slug) as registered,
        (select count(*) from registrations r where r.event = ev.slug and r.status = 'confirmed') as confirmed,
        (select count(*) from registrations r where r.event = ev.slug and r.status = 'attended') as attended
      from events ev order by ev.sort_order
    ) e),
    'gallery_count', (select count(*) from gallery_images)
  );
$$ language sql security definer;

-- ═══════════════════════════════════════════════
-- 8. INDEXES
-- ═══════════════════════════════════════════════
create index if not exists idx_registrations_event on registrations(event);
create index if not exists idx_registrations_status on registrations(status);
create index if not exists idx_registrations_code on registrations(code);
create index if not exists idx_registrations_email on registrations(email);

-- ═══════════════════════════════════════════════
-- 9. STORAGE BUCKET (run separately in Supabase dashboard)
-- ═══════════════════════════════════════════════
-- Create a public bucket called 'gallery' in Supabase Storage
-- insert into storage.buckets (id, name, public) values ('gallery', 'gallery', true);

-- ═══════════════════════════════════════════════
-- 10. ENABLE REALTIME
-- ═══════════════════════════════════════════════
alter publication supabase_realtime add table registrations;
alter publication supabase_realtime add table events;
alter publication supabase_realtime add table gallery_images;
