-- Supabase schema for E-Ticketing Helpdesk

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('user', 'helpdesk', 'admin');
  end if;

  if not exists (select 1 from pg_type where typname = 'ticket_status') then
    create type public.ticket_status as enum ('open', 'assigned', 'in_progress', 'closed');
  end if;
end $$;

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  email text not null unique,
  role public.user_role not null default 'user',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.tickets (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  status public.ticket_status not null default 'open',
  priority text not null default 'medium',
  attachment_url text,
  created_by uuid not null references public.users (id) on delete cascade,
  assigned_to uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ticket_comments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  comment text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ticket_history (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets (id) on delete cascade,
  old_status public.ticket_status,
  new_status public.ticket_status not null,
  changed_by uuid references public.users (id) on delete set null,
  changed_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  ticket_id uuid references public.tickets (id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_tickets_created_by on public.tickets (created_by);
create index if not exists idx_tickets_assigned_to on public.tickets (assigned_to);
create index if not exists idx_ticket_comments_ticket_id on public.ticket_comments (ticket_id);
create index if not exists idx_notifications_user_id on public.notifications (user_id, is_read);

alter table public.users enable row level security;
alter table public.tickets enable row level security;
alter table public.ticket_comments enable row level security;
alter table public.ticket_history enable row level security;
alter table public.notifications enable row level security;

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
as $$
  select coalesce((select role from public.users where id = auth.uid()), 'user'::public.user_role)
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role = 'admin'
  )
$$;

create or replace function public.is_helpdesk()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role = 'helpdesk'
  )
$$;

create or replace function public.is_ticket_owner(ticket_owner uuid)
returns boolean
language sql
stable
as $$
  select ticket_owner = auth.uid()
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.insert_ticket_history()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status then
    insert into public.ticket_history (ticket_id, old_status, new_status, changed_by, changed_at)
    values (new.id, old.status, new.status, auth.uid(), now());
  end if;

  return new;
end;
$$;

create or replace function public.handle_ticket_notifications()
returns trigger
language plpgsql
as $$
begin
  if new.assigned_to is distinct from old.assigned_to and new.assigned_to is not null then
    insert into public.notifications (user_id, ticket_id, title, message)
    values (
      new.assigned_to,
      new.id,
      'Tiket baru ditugaskan',
      'Anda mendapatkan tugas untuk tiket: ' || new.title
    );
  end if;

  if new.status is distinct from old.status then
    if new.created_by is not null then
      insert into public.notifications (user_id, ticket_id, title, message)
      values (
        new.created_by,
        new.id,
        'Status tiket berubah',
        'Status tiket "' || new.title || '" berubah dari ' || old.status::text || ' ke ' || new.status::text
      );
    end if;

    if new.assigned_to is not null and new.assigned_to <> new.created_by then
      insert into public.notifications (user_id, ticket_id, title, message)
      values (
        new.assigned_to,
        new.id,
        'Status tiket diperbarui',
        'Status tiket "' || new.title || '" berubah menjadi ' || new.status::text
      );
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.handle_comment_notifications()
returns trigger
language plpgsql
as $$
declare
  ticket_owner uuid;
  assigned_helpdesk uuid;
begin
  select created_by, assigned_to
    into ticket_owner, assigned_helpdesk
  from public.tickets
  where id = new.ticket_id;

  if ticket_owner is not null and ticket_owner <> new.user_id then
    insert into public.notifications (user_id, ticket_id, title, message)
    values (
      ticket_owner,
      new.ticket_id,
      'Komentar baru',
      'Ada komentar baru pada tiket Anda.'
    );
  end if;

  if assigned_helpdesk is not null and assigned_helpdesk <> new.user_id then
    insert into public.notifications (user_id, ticket_id, title, message)
    values (
      assigned_helpdesk,
      new.ticket_id,
      'Komentar baru',
      'Ada komentar baru pada tiket yang ditugaskan kepada Anda.'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_tickets_touch_updated_at on public.tickets;
create trigger trg_tickets_touch_updated_at
before update on public.tickets
for each row execute function public.touch_updated_at();

drop trigger if exists trg_tickets_history on public.tickets;
create trigger trg_tickets_history
after update on public.tickets
for each row execute function public.insert_ticket_history();

drop trigger if exists trg_tickets_notifications on public.tickets;
create trigger trg_tickets_notifications
after update on public.tickets
for each row execute function public.handle_ticket_notifications();

drop trigger if exists trg_comment_notifications on public.ticket_comments;
create trigger trg_comment_notifications
after insert on public.ticket_comments
for each row execute function public.handle_comment_notifications();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, name, email, role, created_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    new.email,
    coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'user'::public.user_role),
    true,
    now()
  )
  on conflict (id) do update
    set name = excluded.name,
        email = excluded.email,
        role = excluded.role;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- USERS
drop policy if exists "users_select_own_or_admin" on public.users;
create policy "users_select_own_or_admin"
on public.users
for select
to authenticated
using (id = auth.uid() or public.is_admin());

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
on public.users
for insert
to authenticated
with check (id = auth.uid() or public.is_admin());

drop policy if exists "users_update_own_or_admin" on public.users;
create policy "users_update_own_or_admin"
on public.users
for update
to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

drop policy if exists "users_delete_admin" on public.users;
create policy "users_delete_admin"
on public.users
for delete
to authenticated
using (public.is_admin());

-- TICKETS
drop policy if exists "tickets_select_allowed" on public.tickets;
create policy "tickets_select_allowed"
on public.tickets
for select
to authenticated
using (
  public.is_admin()
  or created_by = auth.uid()
  or assigned_to = auth.uid()
);

drop policy if exists "tickets_insert_allowed" on public.tickets;
create policy "tickets_insert_allowed"
on public.tickets
for insert
to authenticated
with check (
  public.is_admin()
  or created_by = auth.uid()
);

drop policy if exists "tickets_update_allowed" on public.tickets;
create policy "tickets_update_allowed"
on public.tickets
for update
to authenticated
using (
  public.is_admin()
  or created_by = auth.uid()
  or (public.is_helpdesk() and assigned_to = auth.uid())
)
with check (
  public.is_admin()
  or created_by = auth.uid()
  or (public.is_helpdesk() and assigned_to = auth.uid())
);

drop policy if exists "tickets_delete_allowed" on public.tickets;
create policy "tickets_delete_allowed"
on public.tickets
for delete
to authenticated
using (
  public.is_admin()
  or created_by = auth.uid()
);

-- COMMENTS
drop policy if exists "comments_select_allowed" on public.ticket_comments;
create policy "comments_select_allowed"
on public.ticket_comments
for select
to authenticated
using (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1 from public.tickets t
    where t.id = ticket_comments.ticket_id
      and (t.created_by = auth.uid() or t.assigned_to = auth.uid())
  )
);

drop policy if exists "comments_insert_allowed" on public.ticket_comments;
create policy "comments_insert_allowed"
on public.ticket_comments
for insert
to authenticated
with check (
  public.is_admin()
  or user_id = auth.uid()
  or exists (
    select 1 from public.tickets t
    where t.id = ticket_id
      and (t.created_by = auth.uid() or t.assigned_to = auth.uid())
  )
);

drop policy if exists "comments_update_allowed" on public.ticket_comments;
create policy "comments_update_allowed"
on public.ticket_comments
for update
to authenticated
using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());

drop policy if exists "comments_delete_allowed" on public.ticket_comments;
create policy "comments_delete_allowed"
on public.ticket_comments
for delete
to authenticated
using (public.is_admin() or user_id = auth.uid());

-- HISTORY
drop policy if exists "history_select_allowed" on public.ticket_history;
create policy "history_select_allowed"
on public.ticket_history
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.tickets t
    where t.id = ticket_history.ticket_id
      and (t.created_by = auth.uid() or t.assigned_to = auth.uid())
  )
);

-- NOTIFICATIONS
drop policy if exists "notifications_select_own_or_admin" on public.notifications;
create policy "notifications_select_own_or_admin"
on public.notifications
for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

drop policy if exists "notifications_update_own_or_admin" on public.notifications;
create policy "notifications_update_own_or_admin"
on public.notifications
for update
to authenticated
using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());

drop policy if exists "notifications_delete_own_or_admin" on public.notifications;
create policy "notifications_delete_own_or_admin"
on public.notifications
for delete
to authenticated
using (public.is_admin() or user_id = auth.uid());
