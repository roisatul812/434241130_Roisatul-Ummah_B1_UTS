# e_ticketing_helpdesk

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Supabase Login Setup

To log in with the three roles, prepare these items:

1. `SUPABASE_URL` and `SUPABASE_ANON_KEY` for the app configuration.
2. Three Supabase Auth accounts, one for each role:
	- User: email and password
	- Helpdesk: email and password
	- Admin: email and password
3. The `public.users` table row for each account with the correct `role` value (`user`, `helpdesk`, `admin`).
4. `is_active = true` for accounts that should be allowed to sign in.

Recommended seed example after creating the Auth users:

```sql
update public.users set role = 'user', is_active = true where email = 'user@example.com';
update public.users set role = 'helpdesk', is_active = true where email = 'helpdesk@example.com';
update public.users set role = 'admin', is_active = true where email = 'admin@example.com';
```

The app uses Supabase Auth for sign in, so the login form only needs email and password. The role is read from the `public.users` profile row after authentication.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
