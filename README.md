# Syntax Technology Business Management System — Connected MVP

This version connects the browser app to your Supabase project.

## 1. Configure Supabase

The project URL is already set in `config.js`.
Open `config.js` and replace:

`sb_publishable_hGrPP0xG245Lhs-pUknc7g_ud_GDOXP`

with the **Publishable key** from Supabase → Project Settings → API Keys.

Do NOT use a secret/service_role key in this file.

Supabase documents publishable keys as the correct key for browser/mobile apps when Row Level Security is enabled.

## 2. Database patch

You already ran the main database SQL. Now open Supabase → SQL Editor → New query, paste the contents of `schema_patch.sql`, and Run it once.

The patch adds:
- authenticated table grants
- automatic profile creation after signup
- atomic inventory adjustment
- low-stock notification creation

## 3. Run the web app

This is a static app and can be opened locally, but browser security can block modules when opening `index.html` directly. Recommended:

```bash
python3 -m http.server 8080
```

Then open:

`http://localhost:8080`

## 4. First account

Use the app's Create account option. New accounts start as `employee`.
After creating your owner account, find its Auth user UUID in Supabase and run:

```sql
update public.profiles set role='admin' where id='YOUR-USER-UUID';
```

## 5. Security

Never put a Supabase secret/service_role key in browser or Android client code. The publishable key is intended to be exposed in client applications; RLS and authenticated sessions protect data access.

## 6. Android

The same web application can be packaged as an Android app in the next stage using Capacitor. This keeps one business interface for web and Android while both use the same Supabase backend.
