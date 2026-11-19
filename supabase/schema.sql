-- INFORMES MAX - esquema completo y migración compatible con la versión anterior.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null, username text not null unique,
 role text not null default 'technician' check(role in ('technician','supervisor')),
 active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.reports (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
 ticket text not null, client text, service text, started_at text, resolved_at text, reported_by text, resolved_by text,
 cause text, description text, solution text, personnel text, materials text, repair_time text, notes text,
 created_at timestamptz not null default now()
);
create table if not exists public.report_photos (
 id uuid primary key default gen_random_uuid(), report_id uuid not null references public.reports(id) on delete cascade,
 user_id uuid not null references public.profiles(id), storage_path text not null unique,
 description text, position int not null check(position between 1 and 8), created_at timestamptz not null default now()
);
-- Nuevos campos: creador, técnico asignado, control de flujo y PDF definitivo.
alter table public.reports add column if not exists created_by uuid references public.profiles(id);
alter table public.reports add column if not exists assigned_to uuid references public.profiles(id);
alter table public.reports add column if not exists status text not null default 'assigned';
alter table public.reports add column if not exists supervisor_started_at timestamptz;
alter table public.reports add column if not exists supervisor_ended_at timestamptz;
alter table public.reports add column if not exists pdf_storage_path text;
alter table public.reports add column if not exists pdf_created_at timestamptz;
alter table public.reports add column if not exists updated_at timestamptz not null default now();
alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports add constraint reports_status_check check(status in ('assigned','in_progress','pending_review','closed'));
update public.reports set created_by=user_id where created_by is null;
update public.reports set assigned_to=user_id where assigned_to is null;
update public.reports set supervisor_started_at=case when started_at is not null and started_at ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then started_at::timestamptz else null end where supervisor_started_at is null;
update public.reports set status='closed' where resolved_at is not null and status='assigned';
alter table public.reports alter column created_by set default auth.uid();
create index if not exists reports_assigned_to_idx on public.reports(assigned_to);
create index if not exists reports_created_at_idx on public.reports(created_at desc);
create index if not exists reports_status_idx on public.reports(status);
create index if not exists reports_ticket_idx on public.reports(ticket);
create index if not exists report_photos_report_idx on public.report_photos(report_id,position);

alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.report_photos enable row level security;
create or replace function public.is_supervisor() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='supervisor' and active=true)
$$;
revoke all on function public.is_supervisor() from public;
grant execute on function public.is_supervisor() to authenticated;

drop policy if exists "profile read self or supervisor" on public.profiles;
drop policy if exists "reports read own or supervisor" on public.reports;
drop policy if exists "reports insert own" on public.reports;
drop policy if exists "reports update own or supervisor" on public.reports;
drop policy if exists "photos read own or supervisor" on public.report_photos;
drop policy if exists "photos insert own" on public.report_photos;
drop policy if exists "profile select own or supervisor" on public.profiles;
drop policy if exists "reports select assigned or supervisor" on public.reports;
drop policy if exists "reports insert supervisor" on public.reports;
drop policy if exists "reports update supervisor" on public.reports;
drop policy if exists "photos select permitted" on public.report_photos;
drop policy if exists "photos insert assigned technician" on public.report_photos;
create policy "profile select own or supervisor" on public.profiles for select to authenticated using(id=auth.uid() or public.is_supervisor());
create policy "reports select assigned or supervisor" on public.reports for select to authenticated using(assigned_to=auth.uid() or user_id=auth.uid() or public.is_supervisor());
create policy "reports insert supervisor" on public.reports for insert to authenticated with check(public.is_supervisor() and created_by=auth.uid());
create policy "reports update supervisor" on public.reports for update to authenticated using(public.is_supervisor()) with check(public.is_supervisor());
create policy "photos select permitted" on public.report_photos for select to authenticated using(user_id=auth.uid() or public.is_supervisor() or exists(select 1 from public.reports r where r.id=report_id and r.assigned_to=auth.uid()));
create policy "photos insert assigned technician" on public.report_photos for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.reports r where r.id=report_id and r.assigned_to=auth.uid() and r.status in ('assigned','in_progress','pending_review')));

-- El técnico solo puede modificar los campos de atención mediante esta función.
create or replace function public.submit_technician_work(p_report_id uuid,p_solution text,p_personnel text,p_materials text,p_repair_time text,p_notes text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and active=true and role='technician') then
  raise exception 'Solo un técnico activo puede enviar la atención';
 end if;
 update public.reports set solution=p_solution,personnel=p_personnel,materials=p_materials,repair_time=p_repair_time,notes=p_notes,status='pending_review',updated_at=now()
 where id=p_report_id and assigned_to=auth.uid() and status in ('assigned','in_progress','pending_review');
 if not found then raise exception 'Ticket no asignado a este técnico o ya cerrado'; end if;
end; $$;
revoke all on function public.submit_technician_work(uuid,text,text,text,text,text) from public;
grant execute on function public.submit_technician_work(uuid,text,text,text,text,text) to authenticated;

-- Buckets privados. Fotos y PDF se guardan fuera de PostgreSQL.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('report-photos','report-photos',false,10485760,array['image/jpeg','image/png','image/webp']),
('report-pdfs','report-pdfs',false,20971520,array['application/pdf'])
on conflict(id) do update set public=false;
drop policy if exists "photo storage read own or supervisor" on storage.objects;
drop policy if exists "photo storage upload own" on storage.objects;
drop policy if exists "photo storage delete own" on storage.objects;
drop policy if exists "photos storage select permitted" on storage.objects;
drop policy if exists "photos storage upload own folder" on storage.objects;
drop policy if exists "pdf storage supervisor only" on storage.objects;
drop policy if exists "pdf storage supervisor upload" on storage.objects;
create policy "photos storage select permitted" on storage.objects for select to authenticated using(bucket_id='report-photos' and (split_part(name,'/',1)=auth.uid()::text or public.is_supervisor() or exists(select 1 from public.reports r where r.id=nullif(split_part(name,'/',2),'')::uuid and r.assigned_to=auth.uid())));
create policy "photos storage upload own folder" on storage.objects for insert to authenticated with check(bucket_id='report-photos' and split_part(name,'/',1)=auth.uid()::text and exists(select 1 from public.reports r where r.id=nullif(split_part(name,'/',2),'')::uuid and r.assigned_to=auth.uid()));
create policy "pdf storage supervisor only" on storage.objects for select to authenticated using(bucket_id='report-pdfs' and public.is_supervisor());
create policy "pdf storage supervisor upload" on storage.objects for insert to authenticated with check(bucket_id='report-pdfs' and public.is_supervisor());
create policy "pdf storage supervisor update" on storage.objects for update to authenticated using(bucket_id='report-pdfs' and public.is_supervisor()) with check(bucket_id='report-pdfs' and public.is_supervisor());
-- Primer supervisor: crear usuario en Authentication y luego insertar su perfil con su UUID.
-- insert into public.profiles(id,full_name,username,role) values ('UUID_AUTH','Supervisor','supervisor','supervisor');

-- Excel de materiales independiente del informe de avería.
alter table public.reports add column if not exists materials_xlsx_storage_path text;
alter table public.reports add column if not exists materials_xlsx_created_at timestamptz;
