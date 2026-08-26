# Supabase setup — a walkthrough

Grocerio works fully offline without any of this. Lists live in Isar on the
phone. Sync, sharing, and community prices turn on **only** when you build
the app with two values (a project URL and a publishable key). Until then,
`SupabaseConfig.isConfigured` is false and the app never opens a network
connection.

This file is the learning path for turning that optional backend on. You do
not need the CLI for the first pass. The dashboard SQL editor is enough.

**Learn:** Supabase is a hosted Postgres database plus user accounts. Postgres
is the actual store; Supabase is the control panel, the login system, and
the API the Flutter app talks to. Think of it as a locked filing cabinet
(the database) with a receptionist (auth) who checks IDs before anyone
opens a drawer.

Estimated time for a first pass: 30–45 minutes, plus however long it takes
to confirm two test emails.

---

## 0. What you will have at the end

- A Supabase project whose tables match `migrations/0001_init.sql`,
  `migrations/0002_sharing.sql`, `migrations/0003_tracked_stores.sql`,
  and `migrations/0004_tombstone_guard.sql`
- Email magic-link login that returns into the Android app
- Two test accounts used to prove that User B cannot read User A's list
  until invited
- A `flutter run` command that actually talks to that project

If you skip the two-account check in section 4, a policy bug can leak other
people's shopping lists and you will not notice until a tester reports it.

---

## 1. Create the project

### 1.1 Sign up and start a project

1. Open [https://supabase.com](https://supabase.com) and create an account
   (GitHub login is fine).
2. Click **New project**.
3. Pick an organization (the personal one is fine).
4. Name it something like `grocerio`.
5. Set a **database password** and store it somewhere you will not lose it.
   You need it for the CLI later, not for the Flutter app.
6. Pick a **region close to your testers** (for example `East US` if they
   are in the eastern United States). This is the physical location of the
   database. Closer usually means a slightly snappier sync.
7. Free tier is enough for closed testing. Create the project and wait until
   the dashboard says it is ready (often one or two minutes).

### 1.2 Copy the two values the app needs

In the left sidebar: **Project Settings** (gear) → **API**.

You want exactly two things:

| Dashboard label | What Grocerio calls it | Safe to put in the app? |
| --- | --- | --- |
| Project URL | `SUPABASE_URL` | Yes |
| Publishable key (older dashboards: **anon public**) | `SUPABASE_PUBLISHABLE_KEY` | Yes |
| **service_role** (secret) | — | **Never** |

**Learn:** the publishable / anon key is not a password. Anyone who unpacks
the APK can read it. That is expected. What stops User B from reading User
A's list is **row-level security** (RLS) — rules inside Postgres that run
on every query. The service_role key bypasses those rules. If it ever lands
in the app, RLS does not matter.

Paste the URL and publishable key into a local note for section 5. Do not
commit them to git.

The project URL looks like `https://abcdefghijklmnop.supabase.co`. The
`abcdefghijklmnop` part is the **project ref**. You will see it again if
you use the CLI.

---

## 2. Apply the schema

This is the step that turns an empty project into Grocerio's backend.

### 2.1 What "schema" means here

A **schema** is the blueprint of the database: table names, columns, which
columns are required, and the security rules.

The Flutter app does **not** create those tables the first time someone
signs in. If you skip this section, sign-in might still work (auth is a
separate Supabase feature), but every sync will fail because `lists` and
`price_reports` do not exist yet.

The blueprint lives in two SQL files in this folder:

| File | What it creates |
| --- | --- |
| [`migrations/0001_init.sql`](migrations/0001_init.sql) | Tables, indexes, RLS policies, invite + delete-account functions |
| [`migrations/0002_sharing.sql`](migrations/0002_sharing.sql) | `list_members_view` — the function the Share sheet uses to show emails |
| [`migrations/0003_tracked_stores.sql`](migrations/0003_tracked_stores.sql) | `user_tracked_stores` — which store locations follow the account |
| [`migrations/0004_tombstone_guard.sql`](migrations/0004_tombstone_guard.sql) | Server trigger: never clear `deleted_at` on lists/items |

They are numbered so you always run **0001 first, then 0002**. 0002 calls
`can_access_list`, which 0001 defines. Running 0002 alone errors.

**Learn:** SQL is the language you use to talk to Postgres. A *migration*
is just a SQL file we treat as "run this to move the empty database to a
known shape." Running the same file twice is mostly safe here because the
statements use `if not exists` / `or replace`, but the intended path is
still: 0001 once, then 0002 once.

### 2.2 Dashboard path (recommended the first time)

You are going to paste file contents into the SQL editor and click Run.
Nothing is deployed to phones yet; this only changes the cloud database.

1. In the Supabase dashboard, open your `grocerio` project.
2. Left sidebar: **SQL Editor**.
3. Click **New query**. You get a blank editor. The name of the query does
   not matter (`init` is a useful name).
4. Open [`migrations/0001_init.sql`](migrations/0001_init.sql) in Cursor.
   Select all, copy.
5. Paste into the SQL editor. You should see comments at the top starting
   with `-- Grocerio backend schema`.
6. Click **Run** (or Ctrl+Enter). Wait until the result panel at the bottom
   reports success. On a healthy run you typically see something like
   "Success. No rows returned" — that is normal. `CREATE TABLE` does not
   return shopping-list rows; it only builds the structure.
7. If it fails, **do not immediately paste 0002**. Read section 2.6.
8. Click **New query** again (keep 0001's tab; starting clean avoids
   accidentally re-running a half-edited mix).
9. Copy [`migrations/0002_sharing.sql`](migrations/0002_sharing.sql), paste,
   **Run**. Success here is the same "no rows returned" message.
10. Copy [`migrations/0003_tracked_stores.sql`](migrations/0003_tracked_stores.sql),
    paste, **Run**. This stores which store locations follow each account.
11. Copy [`migrations/0004_tombstone_guard.sql`](migrations/0004_tombstone_guard.sql),
    paste, **Run**. This keeps a delete on one phone from coming back when
    the other phone syncs a stale live copy.

You now have a database that matches what the Flutter sync code expects.

### 2.3 Confirm the tables actually exist

Left sidebar: **Table Editor**.

You should see at least these tables under `public`:

| Table | What one row is |
| --- | --- |
| `profiles` | One row per auth user (id + email). Filled by a trigger when someone signs up, not by the Flutter app. |
| `lists` | One grocery list. `id` is the same UUID the phone already uses as `publicId`. |
| `list_items` | One item on a list. Linked by `list_id`. |
| `list_members` | "This user may edit this list." Owner is *not* stored here; ownership is `lists.owner_id`. |
| `price_reports` | One shopper-submitted price. Uses catalog/store **slugs** (`milk-whole`, `kroger`), not the integer ids Isar uses on a single phone. |

Click `lists`. The column list should include `owner_id`, `updated_at`, and
`deleted_at`. If those are missing, 0001 did not apply fully.

Also check **Database** → **Functions**. You want at least:

- `handle_new_user` — copies a new auth user into `profiles`
- `is_list_owner` / `can_access_list` — used by RLS so policies do not
  recurse
- `invite_member_by_email` — what the Share sheet calls
- `delete_own_account` — what Account → Delete account calls
- `list_members_view` — from 0002; what the member list calls

If `list_members_view` is missing, 0002 did not run.

### 2.4 What 0001 actually built (so the file is readable)

You do not have to memorize SQL. This is the map.

**Tables**

- `profiles` exists because an invite is "look up this email, attach that
  user to my list." Auth users live in `auth.users`, which the client must
  not scan. The trigger `on_auth_user_created` copies id + email into
  `profiles` the moment someone is created, even if they have never opened
  Grocerio.
- `lists` / `list_items` are the cloud copy of what Isar stores locally.
  `frequency` and `unit` are integers (enum indexes). **Never reorder**
  those enums in Dart without a migration here.
- `canonical_slug` on items (not a local integer id) is the portable
  product identity. Phone A and phone B have different Isar ids for
  "Whole milk"; both have the slug `milk-whole`.
- `deleted_at` is a **tombstone**. The app does not `DELETE` a list row
  when you tap delete. It sets `deleted_at` so the other phone can learn
  "this is gone" instead of thinking "I never had this, I should upload
  it."
- `price_reports` are readable by every signed-in user on purpose.
  Shopper-submitted prices are the whole feature. ZIP filtering happens
  in the app when it *pulls*, so an Ohio report is not shown to a Georgia
  shopper even though the table can contain both.

**Row-level security (RLS)**

After `enable row level security`, a table with **no** policy is invisible
to the client, even with a valid login. 0001 then adds policies such as:

- insert a list only if `owner_id = auth.uid()` (you cannot create a list
  owned by someone else)
- update a list if you own it **or** appear in `list_members`
- delete a list only if you own it
- price reports: anyone signed in may read; only the reporter may change
  theirs
- `profiles`: you can select only your own row (so the client cannot dump
  every email)

**Learn:** `auth.uid()` is "the user id of whoever is making this request."
The Flutter client sends a short-lived token after magic-link login;
Postgres reads that token and fills `auth.uid()`. Policies are checked
inside the database. A cleverly written app cannot skip them. A stolen
anon key also cannot skip them. That is why the anon key is allowed in
the APK.

**SECURITY DEFINER helpers**

`can_access_list` is marked `security definer`, which means it runs with
the privileges of the function owner and **bypasses RLS internally**. That
sounds dangerous; it is the smallest tool that solves a real Postgres
problem.

If a policy on `lists` said "allow if a matching `list_members` row
exists," and a policy on `list_members` said "allow if you can see the
list," Postgres would recurse until it errors. The helper asks both tables
in one place, with RLS off *inside that function only*, then policies call
the helper. The Flutter app cannot call those helpers in a way that
widens access: `invite_member_by_email` still checks `is_list_owner` first.

**RPCs the app actually calls**

| Function | From the app | Why an RPC instead of a table write |
| --- | --- | --- |
| `invite_member_by_email(list_id, email)` | Share sheet | Looks up email inside the database so the client never gets a directory of addresses |
| `delete_own_account()` | Account screen | Deletes `auth.users`; cascades to profiles, lists, memberships, reports |
| `list_members_view(list_id)` | Share sheet member list | Returns emails only for a list you can already access (0002) |

### 2.5 CLI path (optional, later)

Use this when you are tired of copy-paste or you want the same SQL applied
from a terminal. You do **not** need this to finish setup.

1. Install the Supabase CLI ([docs](https://supabase.com/docs/guides/cli)).
2. From this repo's root (the folder that contains `supabase/`):

```bash
supabase login
supabase link --project-ref <your-ref>
supabase db push
```

`<your-ref>` is the subdomain in the Project URL
(`https://<ref>.supabase.co`). `db push` applies every file in
`supabase/migrations/` in name order: 0001, then 0002, then 0003.

If `link` asks for the database password, that is the password from
step 1.1, not the publishable key.

### 2.6 If Run fails

Read the error in the result panel. Typical cases:

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| Syntax error near a line | Accidental edit, or only part of the file pasted | Paste the file again in a **new** query; do not mix 0001 and 0002 in one editor |
| `function can_access_list does not exist` | 0002 ran before 0001 | Run 0001, then 0002 |
| `permission denied` / cannot create extension | Wrong role, or a paused project | Wait until the project shows healthy; stay logged in as the project owner |
| Relation already exists, then later objects missing | A previous partial run | 0001 uses `if not exists` for tables. Re-run the **full** 0001 file, then 0002. Do not drop tables unless you are sure no one has data you care about |
| Policy already exists | Re-running 0001 | 0001 `drop policy if exists` then recreates. Re-run the full file |

Do not "fix" a failure by turning RLS off on a table. An open table with
the anon key in the app is a public dump of every list.

---

## 3. Configure auth

The app supports **email + password** (primary) and **magic link** (optional
fallback). Sessions are stored on the device so relaunching Grocerio keeps
the user signed in until they tap Sign out.

### 3.1 Email provider (required for both password and magic link)

Left sidebar: **Authentication** → **Providers** → **Email**.

1. Enable **Email**.
2. Enable **Email password** sign-ins (sometimes labeled “Allow users to sign
   up with email and password”).
3. For closed testing you may turn **Confirm email** off so create-account
   signs in immediately. Turn confirmation back on before a wide public
   launch if you want to keep throwaway inboxes out.
4. Leave phone / social providers off unless you add them to the Flutter UI
   later. The app currently implements email only.

No SQL migration is required for password auth — `auth.users` already
stores password hashes when Email password is enabled. Your existing
`handle_new_user` trigger still copies each new user into `profiles`.

### 3.2 URL Configuration (Site URL + Redirect URLs)

**Authentication** → **URL Configuration**.

There are **two** fields. Mixing them up is the usual cause of

> Invalid path specified in request URL

when sending magic links or password-reset emails.

#### Site URL (required, must be http/https)

This is the *default* landing place Auth uses when a confirm email has no
`emailRedirectTo`. It must be a normal **https** (or http) URL — **not** the
app deep link.

**Do not leave Site URL as `http://localhost:3000`.** Confirm emails will open
localhost and show “refused to connect.”

After you deploy `netlify-privacy/`, set Site URL to the verified page:

```
https://YOUR_SITE.netlify.app/auth-confirmed.html
```

That page says “Email verified” and offers **Return to Grocerio**.

Do **not** put `io.grocerio://…` in Site URL.

#### Redirect URLs (allowlist)

Click **Add URL** and add **all** of these:

```
https://YOUR_SITE.netlify.app/auth-confirmed.html
io.grocerio://login-callback/
io.grocerio://login-callback
```

The HTTPS entry is for signup confirmation. The deep link must match:

- `SupabaseConfig.authRedirectUrl` in
  `lib/core/backend/supabase_config.dart`
- The Android intent filter in
  `android/app/src/main/AndroidManifest.xml`

Also pass the HTTPS page into the app build so signup emails use it explicitly:

```
--dart-define=AUTH_EMAIL_REDIRECT_URL=https://YOUR_SITE.netlify.app/auth-confirmed.html
```

(see `supabase.defines.example.json`). Password **sign-in** itself does not
need a deep link.

### 3.3 Password reset emails (optional polish)

**Authentication** → **Email Templates** → **Reset password**.

Confirm the link uses `{{ .ConfirmationURL }}` (Supabase default). After the
user opens it, they land via the redirect URL; for a first release it is
enough that they can request a reset from Account → Forgot password.

### 3.4 Play Console test account

Create a dedicated reviewer account in the app (Create account) with a
password you control, then paste into Play Console → App access:

- Email: `your-reviewer@example.com`
- Password: `(the password you set)`
- Notes: “Open Account, sign in with email/password. Lists work without
  sign-in; sharing and community prices need an account.”

### 3.5 Email templates (optional)

**Authentication** → **Email Templates**. The default "Magic Link" mail is
enough for testing. If messages land in spam, check the project's email
settings; on the free tier, volume is limited.

---

## 4. Verify RLS with two accounts

Do this **before** you spend time chasing Flutter bugs. If these checks
fail, the app is not allowed to ship against this project.

### 4.1 Create two users

**Authentication** → **Users** → **Add user** (or Invite).

Create:

- User A — use an inbox you can open
- User B — a second inbox

Copy each user's **UUID** (the `id` column). You will paste them into SQL.

If you add users here before they ever open the app, the `handle_new_user`
trigger should still write `profiles` rows. Confirm in **Table Editor** →
`profiles` that both emails appear. If a profile row is missing, invites
will fail with `user_not_found`.

### 4.2 Impersonate a user in the SQL editor

In **SQL Editor**, open a new query. Look for a role / "run as" control
(wording moves around in the dashboard). You want:

- Role: `authenticated` (not `anon`, not `postgres`)
- User: User A's UUID

`postgres` / `service_role` bypasses RLS. Running the checks as `postgres`
will always "succeed" and teach you nothing.

### 4.3 Checks

Replace `A_UUID`, `B_UUID`, `A_EMAIL`, `B_EMAIL` with the real values.
Pick any UUID for `LIST_ID` (`gen_random_uuid()` in a first statement is
fine — keep it for the later statements).

| Check | Expected |
| --- | --- |
| As A: insert a list with `owner_id = A` | succeeds |
| As A: insert a list with `owner_id = B` | fails (`lists_insert`) |
| As B: `select` A's list | returns nothing |
| As A: `select invite_member_by_email('LIST_ID', 'B_EMAIL')` | succeeds |
| As B: `select` A's list | now returns the row |
| As B: insert a `list_items` row for that list | succeeds |
| As B: delete A's list | fails (`lists_delete` is owner-only) |
| As B: `invite_member_by_email` on A's list | fails (`not_list_owner`) |
| As A or B: `select * from price_reports` | allowed (may be empty) |
| As B: update a report where `reported_by = A` | fails |
| As B: `select * from profiles` | returns only B's row |

If any row behaves differently, fix the SQL / policies and re-run 0001
**before** building a tester APK. RLS mistakes are silent in the UI: the
other person's list simply appears.

---

## 5. Build the app with credentials

From the repo root. **Replace** the placeholders with Project Settings → API
values — do not leave `<ref>` or `<publishable key>` in the command.

PowerShell (one line — `\` line breaks often break on Windows):

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY
```

Or copy [`supabase.defines.example.json`](../supabase.defines.example.json) to
`supabase.defines.json` (gitignored), fill in real values, then:

```powershell
flutter run --dart-define-from-file=supabase.defines.json
```

**Learn:** `--dart-define` bakes the string into the compiled app. It is
not read from a file at runtime unless you use `--dart-define-from-file`.
A build with empty defines is the offline app. A Play/release build needs
the same defines.

Do not wrap values in extra quotes inside the define (`"..."` becoming part
of the URL). The URL must start with `https://` and must **not** include
`/auth/v1` or `/rest/v1` — just `https://YOUR_REF.supabase.co`.

`SUPABASE_ANON_KEY` is accepted as a synonym of `SUPABASE_PUBLISHABLE_KEY`
so older scripts keep working.

### If you see “Invalid path specified in request URL”

That appears on the Account screen when the OTP request is rejected. Fix
dashboard URL config first (section 3.2), then retry:

1. **Site URL** = `https://YOUR_SITE.netlify.app/auth-confirmed.html` (never localhost).
2. **Redirect URLs** includes that HTTPS page plus `io.grocerio://login-callback/`
   (and the no-slash variant).
3. Rebuild with `AUTH_EMAIL_REDIRECT_URL` set to the same HTTPS page.
4. Re-run `flutter run` with correct dart-defines (no quotes in the values).
5. Use an Android device/emulator for the first successful magic-link open.

### On the phone (after the email sends)

1. Open the drawer → **Account**
2. Enter your email → **Email me a link**
3. Open the mail **on that phone**
4. You should land back in Grocerio, signed in
5. Pull to refresh on Home — that is a sync
6. Open a list → ⋮ → **Share with people** → invite B's email (B must
   already have a profile row, which they get by signing in once)

If the link opens Chrome and dies, section 3.2 is wrong. If sync snackbars
fail immediately, section 2 probably did not apply (check Table Editor).

---

## What syncs

| Data | Direction | Notes |
| --- | --- | --- |
| Lists and items | Both ways | Last-write-wins per row on `updated_at`; deletes are tombstones |
| List membership | Pull | Created by the owner through `invite_member_by_email` |
| Price reports | Both ways | The app only *keeps* reports whose ZIP prefix matches the shopper |
| Preferences, catalog, stores | Never | Device-local by design |

Local Isar remains what the UI reads. The network is a background copy, not
a requirement for opening a list.
