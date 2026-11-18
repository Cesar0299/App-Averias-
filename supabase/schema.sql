create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null,
 username text not null unique,
 role text not null default 'technician' check (role in ('technician','supervisor')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.reports (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id),
 ticket text not null,
 client text, service text, started_at text, resolved_at text, reported_by text, resolved_by text,
 cause text, description text, solution text, personnel text, materials text, repair_time text, notes text,
 created_at timestamptz not null default now()
);
create table if not exists public.report_photos (
 id uuid primary key default gen_random_uuid(),
 report_id uuid not null references public.reports(id) on delete cascade,
 user_id uuid not null references public.profiles(id),
 storage_path text not null unique,
 description text,
 position int not null check(position between 1 and 8),
 created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.report_photos enable row level security;
create or replace function public.is_supervisor() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='supervisor' and active=true) $$;
create policy "profile read self or supervisor" on public.profiles for select to authenticated using (id=auth.uid() or public.is_supervisor());
create policy "reports read own or supervisor" on public.reports for select to authenticated using (user_id=auth.uid() or public.is_supervisor());
create policy "reports insert own" on public.reports for insert to authenticated with check (user_id=auth.uid());
create policy "reports update own or supervisor" on public.reports for update to authenticated using (user_id=auth.uid() or public.is_supervisor()) with check (user_id=auth.uid() or public.is_supervisor());
create policy "photos read own or supervisor" on public.report_photos for select to authenticated using (user_id=auth.uid() or public.is_supervisor());
create policy "photos insert own" on public.report_photos for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.reports r where r.id=report_id and r.user_id=auth.uid()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('report-photos','report-photos',false,10485760,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy "photo storage read own or supervisor" on storage.objects for select to authenticated using (bucket_id='report-photos' and (split_part(name,'/',1)=auth.uid()::text or public.is_supervisor()));
create policy "photo storage upload own" on storage.objects for insert to authenticated with check (bucket_id='report-photos' and split_part(name,'/',1)=auth.uid()::text);
create policy "photo storage delete own" on storage.objects for delete to authenticated using (bucket_id='report-photos' and split_part(name,'/',1)=auth.uid()::text);
-- Después de crear el primer usuario supervisor desde Authentication, inserta su perfil:
-- insert into public.profiles(id,full_name,username,role) values ('UUID_DEL_USUARIO','Supervisor','supervisor','supervisor');
