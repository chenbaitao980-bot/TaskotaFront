create table if not exists public.allowed_users (
  email text primary key,
  created_at timestamptz not null default now()
);

create table if not exists public.dynamic_secrets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  environment text not null default 'default',
  ciphertext text not null,
  iv text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.dynamic_data (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.managed_apps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  url text,
  status text not null default 'active' check (status in ('active', 'paused', 'archived')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists dynamic_secrets_set_updated_at on public.dynamic_secrets;
create trigger dynamic_secrets_set_updated_at
before update on public.dynamic_secrets
for each row execute function public.set_updated_at();

drop trigger if exists dynamic_data_set_updated_at on public.dynamic_data;
create trigger dynamic_data_set_updated_at
before update on public.dynamic_data
for each row execute function public.set_updated_at();

drop trigger if exists managed_apps_set_updated_at on public.managed_apps;
create trigger managed_apps_set_updated_at
before update on public.managed_apps
for each row execute function public.set_updated_at();

alter table public.allowed_users enable row level security;
alter table public.dynamic_secrets enable row level security;
alter table public.dynamic_data enable row level security;
alter table public.managed_apps enable row level security;

drop policy if exists "allowed users can read own allowlist row" on public.allowed_users;
create policy "allowed users can read own allowlist row"
on public.allowed_users for select
to authenticated
using (email = auth.jwt() ->> 'email');

drop policy if exists "owner can manage secrets" on public.dynamic_secrets;
create policy "owner can manage secrets"
on public.dynamic_secrets for all
to authenticated
using (
  user_id = auth.uid()
  and exists (select 1 from public.allowed_users where email = auth.jwt() ->> 'email')
)
with check (
  user_id = auth.uid()
  and exists (select 1 from public.allowed_users where email = auth.jwt() ->> 'email')
);

drop policy if exists "owner can manage data" on public.dynamic_data;
create policy "owner can manage data"
on public.dynamic_data for all
to authenticated
using (
  user_id = auth.uid()
  and exists (select 1 from public.allowed_users where email = auth.jwt() ->> 'email')
)
with check (
  user_id = auth.uid()
  and exists (select 1 from public.allowed_users where email = auth.jwt() ->> 'email')
);

drop policy if exists "owner can manage apps" on public.managed_apps;
create policy "owner can manage apps"
on public.managed_apps for all
to authenticated
using (
  user_id = auth.uid()
  and exists (select 1 from public.allowed_users where email = auth.jwt() ->> 'email')
)
with check (
  user_id = auth.uid()
  and exists (select 1 from public.allowed_users where email = auth.jwt() ->> 'email')
);

-- Replace this with your own login email before running.
insert into public.allowed_users (email)
values ('your-email@example.com')
on conflict (email) do nothing;
