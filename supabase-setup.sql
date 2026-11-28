-- =========================================================
-- SARISAFE: COMPLETE SUPABASE DATABASE SETUP
-- Zero-login tender auto-sync (upload-only) + Owner-only full read
-- =========================================================

-- 1. CREATE THE STORE
create table if not exists public.sarisafe_stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

insert into public.sarisafe_stores (id, name)
values (
  '11111111-1111-4111-8111-111111111111',
  'Fuentez Store'
)
on conflict (id) do nothing;


-- 2. CREATE USER PROFILES
create table if not exists public.sarisafe_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  store_id uuid not null references public.sarisafe_stores(id),
  full_name text,
  role text not null check (role in ('owner', 'staff')),
  created_at timestamptz not null default now()
);

alter table public.sarisafe_profiles
  add column if not exists full_name text;


-- 3. CREATE TRANSACTIONS TABLE
create table if not exists public.sarisafe_transactions (
  id text primary key,
  ts timestamptz not null,
  data jsonb not null,
  store_id uuid,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table public.sarisafe_transactions
  add column if not exists store_id uuid,
  add column if not exists created_by uuid references auth.users(id),
  add column if not exists updated_by uuid references auth.users(id),
  add column if not exists updated_at timestamptz default now();

update public.sarisafe_transactions
set store_id = '11111111-1111-4111-8111-111111111111'
where store_id is null;

alter table public.sarisafe_transactions
  alter column store_id set not null;


-- 4. CREATE SHIFTS TABLE
create table if not exists public.sarisafe_shifts (
  id text primary key,
  ts timestamptz not null,
  data jsonb not null,
  store_id uuid,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table public.sarisafe_shifts
  add column if not exists store_id uuid,
  add column if not exists created_by uuid references auth.users(id),
  add column if not exists updated_by uuid references auth.users(id),
  add column if not exists updated_at timestamptz default now();

update public.sarisafe_shifts
set store_id = '11111111-1111-4111-8111-111111111111'
where store_id is null;

alter table public.sarisafe_shifts
  alter column store_id set not null;


-- 5. ADD STORE FOREIGN KEYS
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'sarisafe_transactions_store_fk'
      and conrelid = 'public.sarisafe_transactions'::regclass
  ) then
    alter table public.sarisafe_transactions
      add constraint sarisafe_transactions_store_fk
      foreign key (store_id)
      references public.sarisafe_stores(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'sarisafe_shifts_store_fk'
      and conrelid = 'public.sarisafe_shifts'::regclass
  ) then
    alter table public.sarisafe_shifts
      add constraint sarisafe_shifts_store_fk
      foreign key (store_id)
      references public.sarisafe_stores(id);
  end if;
end;
$$;


-- 6. INDEXES FOR FASTER SYNCHRONIZATION
create index if not exists sarisafe_tx_upd on public.sarisafe_transactions(updated_at);
create index if not exists sarisafe_sh_upd on public.sarisafe_shifts(updated_at);
create index if not exists sarisafe_tx_store on public.sarisafe_transactions(store_id);
create index if not exists sarisafe_sh_store on public.sarisafe_shifts(store_id);


-- 7. HELPER FUNCTIONS FOR STORE & ROLE LOOKUP
create or replace function public.current_sarisafe_store_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select store_id
  from public.sarisafe_profiles
  where user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_sarisafe_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select role
  from public.sarisafe_profiles
  where user_id = auth.uid()
  limit 1;
$$;


-- 8. AUTOMATIC USER, IMMUTABILITY, AND TIMESTAMP TRACKING
create or replace function public.sarisafe_touch()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.store_id is null then
      new.store_id := public.current_sarisafe_store_id();
    end if;

    new.created_by := auth.uid();
    new.updated_by := auth.uid();
  else
    -- Enforce immutability of recorded transaction financial fields and signatures.
    if tg_table_name = 'sarisafe_transactions' and (
      new.data->>'kind'   is distinct from old.data->>'kind' or
      new.data->>'amount' is distinct from old.data->>'amount' or
      new.data->>'fee'    is distinct from old.data->>'fee' or
      new.data->>'ref'    is distinct from old.data->>'ref' or
      new.data->>'type'   is distinct from old.data->>'type' or
      new.data->>'sig'    is distinct from old.data->>'sig'
    ) then
      raise exception 'Recorded transaction financial fields and signatures are immutable';
    end if;

    new.store_id := old.store_id;
    new.created_by := old.created_by;
    new.updated_by := auth.uid();
  end if;

  new.updated_at := now();
  return new;
end;
$$;


-- 9. ATTACH TRIGGERS
drop trigger if exists sarisafe_tx_touch on public.sarisafe_transactions;
create trigger sarisafe_tx_touch
before insert or update on public.sarisafe_transactions
for each row execute function public.sarisafe_touch();

drop trigger if exists sarisafe_sh_touch on public.sarisafe_shifts;
create trigger sarisafe_sh_touch
before insert or update on public.sarisafe_shifts
for each row execute function public.sarisafe_touch();


-- 10. ZERO-LOGIN TENDER UPLOAD FUNCTION (WRITE-ONLY, NO READ ACCESS)
create or replace function public.sarisafe_tender_sync(
  p_txs jsonb default '[]'::jsonb,
  p_shifts jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_store_id uuid := '11111111-1111-4111-8111-111111111111';
  v_item jsonb;
  v_id text;
  v_ts timestamptz;
begin
  -- Upload shifts
  if jsonb_typeof(p_shifts) = 'array' then
    for v_item in select * from jsonb_array_elements(p_shifts)
    loop
      v_id := nullif(trim(v_item->>'id'), '');
      if v_id is null or length(v_id) > 64 then
        continue;
      end if;
      v_ts := coalesce(nullif(v_item->>'startedAt', '')::timestamptz, now());

      insert into public.sarisafe_shifts (id, ts, data, store_id, updated_at)
      values (v_id, v_ts, v_item, v_store_id, now())
      on conflict (id) do update
        set data = excluded.data,
            updated_at = now();
    end loop;
  end if;

  -- Upload transactions (preserving immutable financial fields and signatures)
  if jsonb_typeof(p_txs) = 'array' then
    for v_item in select * from jsonb_array_elements(p_txs)
    loop
      v_id := nullif(trim(v_item->>'id'), '');
      if v_id is null or length(v_id) > 64 then
        continue;
      end if;
      v_ts := coalesce(nullif(v_item->>'ts', '')::timestamptz, now());

      insert into public.sarisafe_transactions (id, ts, data, store_id, updated_at)
      values (v_id, v_ts, v_item, v_store_id, now())
      on conflict (id) do update
        set data = case
          when (
            excluded.data->>'kind'   is distinct from sarisafe_transactions.data->>'kind' or
            excluded.data->>'amount' is distinct from sarisafe_transactions.data->>'amount' or
            excluded.data->>'fee'    is distinct from sarisafe_transactions.data->>'fee' or
            excluded.data->>'ref'    is distinct from sarisafe_transactions.data->>'ref' or
            excluded.data->>'type'   is distinct from sarisafe_transactions.data->>'type' or
            excluded.data->>'sig'    is distinct from sarisafe_transactions.data->>'sig'
          ) then sarisafe_transactions.data
          else excluded.data
        end,
        updated_at = now();
    end loop;
  end if;

  return jsonb_build_object('ok', true);
end;
$$;


-- 11. ENABLE ROW LEVEL SECURITY
alter table public.sarisafe_stores enable row level security;
alter table public.sarisafe_profiles enable row level security;
alter table public.sarisafe_transactions enable row level security;
alter table public.sarisafe_shifts enable row level security;


-- 12. CLEAN UP OLD POLICIES
drop policy if exists "store read" on public.sarisafe_transactions;
drop policy if exists "store insert" on public.sarisafe_transactions;
drop policy if exists "store update" on public.sarisafe_transactions;
drop policy if exists "store read" on public.sarisafe_shifts;
drop policy if exists "store insert" on public.sarisafe_shifts;
drop policy if exists "store update" on public.sarisafe_shifts;

drop policy if exists "sarisafe_store_read" on public.sarisafe_stores;
drop policy if exists "sarisafe_profiles_read" on public.sarisafe_profiles;
drop policy if exists "sarisafe_transactions_read" on public.sarisafe_transactions;
drop policy if exists "sarisafe_transactions_insert" on public.sarisafe_transactions;
drop policy if exists "sarisafe_transactions_update" on public.sarisafe_transactions;
drop policy if exists "sarisafe_shifts_read" on public.sarisafe_shifts;
drop policy if exists "sarisafe_shifts_insert" on public.sarisafe_shifts;
drop policy if exists "sarisafe_shifts_update" on public.sarisafe_shifts;


-- 13. OWNER-ONLY POLICIES
create policy "sarisafe_store_read"
on public.sarisafe_stores
for select to authenticated
using (id = public.current_sarisafe_store_id());

create policy "sarisafe_profiles_read"
on public.sarisafe_profiles
for select to authenticated
using (
  user_id = auth.uid()
  or (
    store_id = public.current_sarisafe_store_id()
    and public.current_sarisafe_role() = 'owner'
  )
);

-- ONLY the Store Owner can read transactions across all devices
create policy "sarisafe_transactions_read"
on public.sarisafe_transactions
for select to authenticated
using (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
);

create policy "sarisafe_transactions_insert"
on public.sarisafe_transactions
for insert to authenticated
with check (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
);

create policy "sarisafe_transactions_update"
on public.sarisafe_transactions
for update to authenticated
using (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
)
with check (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
);

-- ONLY the Store Owner can read shifts across all devices
create policy "sarisafe_shifts_read"
on public.sarisafe_shifts
for select to authenticated
using (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
);

create policy "sarisafe_shifts_insert"
on public.sarisafe_shifts
for insert to authenticated
with check (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
);

create policy "sarisafe_shifts_update"
on public.sarisafe_shifts
for update to authenticated
using (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
)
with check (
  store_id = public.current_sarisafe_store_id()
  and public.current_sarisafe_role() = 'owner'
);


-- 14. GRANT PERMISSIONS (Anonymous tenders can ONLY call the upload function, never SELECT)
revoke all on public.sarisafe_stores, public.sarisafe_profiles, public.sarisafe_transactions, public.sarisafe_shifts from anon;
grant usage on schema public to anon, authenticated;
grant execute on function public.sarisafe_tender_sync(jsonb, jsonb) to anon, authenticated;
grant select on public.sarisafe_stores, public.sarisafe_profiles to authenticated;
grant select, insert, update on public.sarisafe_transactions, public.sarisafe_shifts to authenticated;
grant execute on function public.current_sarisafe_store_id() to authenticated;
grant execute on function public.current_sarisafe_role() to authenticated;


-- 15. LINK YOUR STORE OWNER ACCOUNT
insert into public.sarisafe_profiles (user_id, store_id, full_name, role)
select id, '11111111-1111-4111-8111-111111111111', 'Store Owner', 'owner'
from auth.users
where id = '7e7d0993-85a4-465c-9139-e734f11f4d53'
on conflict (user_id) do update
  set store_id = excluded.store_id,
      full_name = excluded.full_name,
      role = excluded.role;

      -- 16. POST-SETUP VERIFICATION QUERIES (Optional read-only checks)
-- Run these individually in the Supabase SQL Editor to verify tables, RLS, and owner setup:
-- select tablename, rowsecurity from pg_tables where schemaname = 'public' and tablename like 'sarisafe_%';
-- select store_id, full_name, role from public.sarisafe_profiles where role = 'owner';