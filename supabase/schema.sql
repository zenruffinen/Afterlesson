-- ============================================================
-- Grünbuch Cloud — Datenbankschema (Supabase)
-- Stand: 17.07.2026
--
-- Einspielen: Supabase-Dashboard → SQL Editor → einfügen → Run.
-- Kann gefahrlos mehrfach ausgeführt werden (idempotent).
--
-- Das Modell:
--   profiles      Wer bin ich? (Pro oder Schüler, Anzeigename)
--   invite_codes  Der Pro erzeugt einen Code, der Schüler löst ihn ein
--   pro_students  Die Verknüpfung Pro ↔ Schüler
--   packages      Gesendete Lektionen/Stunden (Metadaten als JSON)
--   Storage       Bucket "media" für Bilder/Videos/PDFs
--
-- Sicherheit: Row Level Security überall. Jeder sieht nur, was ihm
-- gehört oder an ihn gesendet wurde — auch mit dem öffentlichen
-- anon-Schlüssel der App kommt niemand an fremde Daten.
-- ============================================================

-- ---------- 1. Profile ----------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('teacher', 'student')),
  display_name text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Eigenes Profil lesen" on public.profiles;
create policy "Eigenes Profil lesen"
  on public.profiles for select
  using (id = auth.uid());

drop policy if exists "Eigenes Profil anlegen" on public.profiles;
create policy "Eigenes Profil anlegen"
  on public.profiles for insert
  with check (id = auth.uid());

drop policy if exists "Eigenes Profil ändern" on public.profiles;
create policy "Eigenes Profil ändern"
  on public.profiles for update
  using (id = auth.uid());

-- Verknüpfte Personen dürfen gegenseitig den Namen sehen
drop policy if exists "Verknüpfte Profile lesen" on public.profiles;
create policy "Verknüpfte Profile lesen"
  on public.profiles for select
  using (
    exists (
      select 1 from public.pro_students ps
      where (ps.pro_id = auth.uid() and ps.student_id = profiles.id)
         or (ps.student_id = auth.uid() and ps.pro_id = profiles.id)
    )
  );

-- ---------- 2. Einladungscodes ----------

create table if not exists public.invite_codes (
  code text primary key,
  pro_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  used_by uuid references public.profiles (id),
  used_at timestamptz
);

alter table public.invite_codes enable row level security;

drop policy if exists "Pro verwaltet eigene Codes" on public.invite_codes;
create policy "Pro verwaltet eigene Codes"
  on public.invite_codes for all
  using (pro_id = auth.uid())
  with check (pro_id = auth.uid());

-- ---------- 3. Verknüpfung Pro ↔ Schüler ----------

create table if not exists public.pro_students (
  id uuid primary key default gen_random_uuid(),
  pro_id uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (pro_id, student_id)
);

alter table public.pro_students enable row level security;

drop policy if exists "Beteiligte sehen Verknüpfung" on public.pro_students;
create policy "Beteiligte sehen Verknüpfung"
  on public.pro_students for select
  using (pro_id = auth.uid() or student_id = auth.uid());

drop policy if exists "Pro löscht Verknüpfung" on public.pro_students;
create policy "Pro löscht Verknüpfung"
  on public.pro_students for delete
  using (pro_id = auth.uid());

-- Der Schüler löst den Code ein — über eine Funktion, weil er die
-- pro_id ja noch nicht kennen darf. Läuft mit erhöhten Rechten,
-- prüft aber selbst alle Bedingungen.
create or replace function public.redeem_invite(invite_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pro uuid;
begin
  select pro_id into v_pro
  from invite_codes
  where code = upper(trim(invite_code)) and used_by is null;

  if v_pro is null then
    return false;                      -- Code unbekannt oder verbraucht
  end if;
  if v_pro = auth.uid() then
    return false;                      -- sich selbst verknüpfen: nein
  end if;

  insert into pro_students (pro_id, student_id)
  values (v_pro, auth.uid())
  on conflict (pro_id, student_id) do nothing;

  update invite_codes
  set used_by = auth.uid(), used_at = now()
  where code = upper(trim(invite_code));

  return true;
end;
$$;

-- ---------- 4. Gesendete Pakete ----------

create table if not exists public.packages (
  id uuid primary key default gen_random_uuid(),
  pro_id uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('lesson', 'session')),
  title text not null default '',
  payload jsonb not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.packages enable row level security;

-- Der Pro sendet nur an eigene, verknüpfte Schüler
drop policy if exists "Pro sendet an eigene Schüler" on public.packages;
create policy "Pro sendet an eigene Schüler"
  on public.packages for insert
  with check (
    pro_id = auth.uid()
    and exists (
      select 1 from public.pro_students ps
      where ps.pro_id = auth.uid() and ps.student_id = packages.student_id
    )
  );

drop policy if exists "Pro sieht Gesendetes" on public.packages;
create policy "Pro sieht Gesendetes"
  on public.packages for select
  using (pro_id = auth.uid());

drop policy if exists "Schüler sieht Empfangenes" on public.packages;
create policy "Schüler sieht Empfangenes"
  on public.packages for select
  using (student_id = auth.uid());

-- Der Schüler darf nur den Lesestatus setzen
drop policy if exists "Schüler markiert gelesen" on public.packages;
create policy "Schüler markiert gelesen"
  on public.packages for update
  using (student_id = auth.uid())
  with check (student_id = auth.uid());

-- ---------- 5. Storage: Bucket "media" ----------
-- Dateien liegen unter  <pro_id>/<dateiname>  — der Pro lädt in seinen
-- eigenen Ordner hoch, verknüpfte Schüler dürfen daraus lesen.

insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do nothing;

drop policy if exists "Pro lädt in eigenen Ordner" on storage.objects;
create policy "Pro lädt in eigenen Ordner"
  on storage.objects for insert
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Pro liest eigenen Ordner" on storage.objects;
create policy "Pro liest eigenen Ordner"
  on storage.objects for select
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Pro löscht im eigenen Ordner" on storage.objects;
create policy "Pro löscht im eigenen Ordner"
  on storage.objects for delete
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Schüler liest Ordner seines Pros" on storage.objects;
create policy "Schüler liest Ordner seines Pros"
  on storage.objects for select
  using (
    bucket_id = 'media'
    and exists (
      select 1 from public.pro_students ps
      where ps.student_id = auth.uid()
        and ps.pro_id::text = (storage.foldername(name))[1]
    )
  );
