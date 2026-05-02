-- profiles table, linked to auth.users
create table if not exists public.profiles (
  id          uuid references auth.users on delete cascade not null primary key,
  email       text,
  full_name   text,
  role        text not null default 'user',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "users_select_own" on public.profiles
  for select using (auth.uid() = id);

create policy "users_update_own" on public.profiles
  for update using (auth.uid() = id)
  with check (role = (select role from public.profiles where id = auth.uid()));

create policy "admins_all" on public.profiles
  for all using (
    (select role from public.profiles where id = auth.uid()) = 'admin'
  );

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
