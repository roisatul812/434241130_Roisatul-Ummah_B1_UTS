-- =========================================================================
-- DATABASE EXPORT - E-Ticketing Helpdesk (Supabase / PostgreSQL)
-- Aplikasi Mobile - UAS - DIV Teknik Informatika Universitas Airlangga
-- =========================================================================
-- File ini adalah gabungan seluruh script SQL yang mendefinisikan struktur
-- database aplikasi: tabel, enum, trigger, function, RLS policy (tabel
-- maupun storage). Jalankan file ini secara berurutan dari atas ke bawah
-- pada project Supabase baru untuk mereplikasi struktur database yang sama.
-- =========================================================================


-- #########################################################################
-- BAGIAN 1: SKEMA TABEL (enum, tabel utama, trigger riwayat status)
-- #########################################################################

-- 1.1 ENUM TYPES
create type user_role as enum ('user', 'helpdesk', 'admin');
create type ticket_status as enum ('open', 'assigned', 'in_progress', 'closed');
create type ticket_priority as enum ('low', 'medium', 'high');

-- 1.2 TABEL: users (profile tambahan, terhubung ke auth.users)
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique,
  role user_role not null default 'user',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 1.3 TABEL: tickets
create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  status ticket_status not null default 'open',
  priority ticket_priority not null default 'medium',
  attachment_url text,
  created_by uuid not null references public.users(id) on delete cascade,
  assigned_to uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 1.4 TABEL: ticket_comments
create table public.ticket_comments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  comment text not null,
  created_at timestamptz not null default now()
);

-- 1.5 TABEL: ticket_history
create table public.ticket_history (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  old_status ticket_status,
  new_status ticket_status not null,
  changed_by uuid not null references public.users(id) on delete cascade,
  changed_at timestamptz not null default now()
);

-- 1.6 TABEL: notifications
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  ticket_id uuid references public.tickets(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- 1.7 TRIGGER: catat riwayat setiap kali status tiket berubah
-- (changed_by diisi dengan auth.uid() = user yang sedang login dan
--  melakukan perubahan, BUKAN assigned_to tiket)
create or replace function public.log_ticket_status_change()
returns trigger as $$
begin
  if old.status is distinct from new.status then
    insert into public.ticket_history (ticket_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
  end if;
  new.updated_at = now();
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_ticket_status_change
before update on public.tickets
for each row
execute function public.log_ticket_status_change();

-- 1.8 AKTIFKAN ROW LEVEL SECURITY
alter table public.users enable row level security;
alter table public.tickets enable row level security;
alter table public.ticket_comments enable row level security;
alter table public.ticket_history enable row level security;
alter table public.notifications enable row level security;

-- 1.9 HELPER FUNCTION: ambil role user yang sedang login
create or replace function public.current_user_role()
returns user_role as $$
  select role from public.users where id = auth.uid();
$$ language sql stable security definer;

-- 1.10 RLS POLICY: users
create policy "users_select_all_authenticated"
on public.users for select
to authenticated
using (true);

create policy "users_update_own_profile"
on public.users for update
to authenticated
using (id = auth.uid());

create policy "users_admin_manage"
on public.users for all
to authenticated
using (public.current_user_role() = 'admin');

-- 1.11 RLS POLICY: tickets
create policy "tickets_select"
on public.tickets for select
to authenticated
using (
  created_by = auth.uid()
  or assigned_to = auth.uid()
  or public.current_user_role() = 'admin'
);

create policy "tickets_insert"
on public.tickets for insert
to authenticated
with check (created_by = auth.uid());

create policy "tickets_update"
on public.tickets for update
to authenticated
using (
  created_by = auth.uid()
  or assigned_to = auth.uid()
  or public.current_user_role() = 'admin'
);

create policy "tickets_delete_admin_only"
on public.tickets for delete
to authenticated
using (public.current_user_role() = 'admin');

-- 1.12 RLS POLICY: ticket_comments
create policy "comments_select"
on public.ticket_comments for select
to authenticated
using (
  exists (
    select 1 from public.tickets t
    where t.id = ticket_id
      and (t.created_by = auth.uid() or t.assigned_to = auth.uid() or public.current_user_role() = 'admin')
  )
);

create policy "comments_insert"
on public.ticket_comments for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.tickets t
    where t.id = ticket_id
      and (t.created_by = auth.uid() or t.assigned_to = auth.uid() or public.current_user_role() = 'admin')
  )
);

-- 1.13 RLS POLICY: ticket_history
create policy "history_select"
on public.ticket_history for select
to authenticated
using (
  exists (
    select 1 from public.tickets t
    where t.id = ticket_id
      and (t.created_by = auth.uid() or t.assigned_to = auth.uid() or public.current_user_role() = 'admin')
  )
);

-- 1.14 RLS POLICY: notifications
create policy "notifications_select_own"
on public.notifications for select
to authenticated
using (user_id = auth.uid());

create policy "notifications_update_own"
on public.notifications for update
to authenticated
using (user_id = auth.uid());

create policy "notifications_insert"
on public.notifications for insert
to authenticated
with check (true);


-- #########################################################################
-- BAGIAN 2: STORAGE POLICY (bucket "ticket-attachments")
-- #########################################################################
-- Catatan: bucket "ticket-attachments" (public) harus dibuat manual lewat
-- menu Storage di dashboard Supabase sebelum menjalankan policy di bawah.

create policy "ticket_attachments_upload"
on storage.objects for insert
to authenticated
with check (bucket_id = 'ticket-attachments');

create policy "ticket_attachments_select"
on storage.objects for select
to authenticated
using (bucket_id = 'ticket-attachments');

create policy "ticket_attachments_delete_own"
on storage.objects for delete
to authenticated
using (bucket_id = 'ticket-attachments' and owner = auth.uid());


-- #########################################################################
-- BAGIAN 3: TRIGGER OTOMATIS - PROFIL USER BARU (Register via aplikasi)
-- #########################################################################

create or replace function public.handle_new_auth_user()
returns trigger as $$
begin
  insert into public.users (id, name, email, role, is_active)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    new.email,
    'user',
    true
  )
  on conflict (id) do nothing;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger trg_handle_new_auth_user
after insert on auth.users
for each row
execute function public.handle_new_auth_user();


-- #########################################################################
-- BAGIAN 4: TRIGGER OTOMATIS - NOTIFIKASI AKTIVITAS TIKET
-- #########################################################################

-- 4.1 Tiket baru dibuat -> semua Admin aktif dapat notifikasi
create or replace function public.notify_new_ticket()
returns trigger as $$
declare
  admin_row record;
begin
  for admin_row in
    select id from public.users where role = 'admin' and is_active = true
  loop
    insert into public.notifications (user_id, title, message, ticket_id)
    values (
      admin_row.id,
      'Tiket baru masuk',
      'Tiket baru "' || new.title || '" telah dibuat dan menunggu di-assign.',
      new.id
    );
  end loop;

  return new;
end;
$$ language plpgsql security definer;

create trigger trg_notify_new_ticket
after insert on public.tickets
for each row
execute function public.notify_new_ticket();

-- 4.2 Tiket di-assign / status berubah
--     -> Helpdesk yang ditugaskan & User pembuat tiket dapat notifikasi
create or replace function public.notify_ticket_update()
returns trigger as $$
begin
  if new.assigned_to is not null
     and (old.assigned_to is distinct from new.assigned_to) then
    insert into public.notifications (user_id, title, message, ticket_id)
    values (
      new.assigned_to,
      'Tiket baru ditugaskan',
      'Tiket "' || new.title || '" telah di-assign ke Anda.',
      new.id
    );
  end if;

  if old.status is distinct from new.status then
    insert into public.notifications (user_id, title, message, ticket_id)
    values (
      new.created_by,
      'Status tiket diperbarui',
      'Tiket "' || new.title || '" sekarang berstatus ' || new.status || '.',
      new.id
    );
  end if;

  return new;
end;
$$ language plpgsql security definer;

create trigger trg_notify_ticket_update
after update on public.tickets
for each row
execute function public.notify_ticket_update();

-- 4.3 Komentar baru -> pembuat tiket & helpdesk yang ditugaskan
--     dapat notifikasi (kecuali penulis komentar itu sendiri)
create or replace function public.notify_new_comment()
returns trigger as $$
declare
  ticket_row record;
begin
  select created_by, assigned_to, title into ticket_row
  from public.tickets
  where id = new.ticket_id;

  if ticket_row.created_by is not null and ticket_row.created_by != new.user_id then
    insert into public.notifications (user_id, title, message, ticket_id)
    values (
      ticket_row.created_by,
      'Komentar baru',
      'Ada komentar baru di tiket "' || ticket_row.title || '".',
      new.ticket_id
    );
  end if;

  if ticket_row.assigned_to is not null and ticket_row.assigned_to != new.user_id then
    insert into public.notifications (user_id, title, message, ticket_id)
    values (
      ticket_row.assigned_to,
      'Komentar baru',
      'Ada komentar baru di tiket "' || ticket_row.title || '".',
      new.ticket_id
    );
  end if;

  return new;
end;
$$ language plpgsql security definer;

create trigger trg_notify_new_comment
after insert on public.ticket_comments
for each row
execute function public.notify_new_comment();

-- =========================================================================
-- SELESAI - Total: 5 tabel, 3 enum, 7 function, 6 trigger, 14 RLS policy
-- (11 policy tabel + 3 policy storage)
-- =========================================================================