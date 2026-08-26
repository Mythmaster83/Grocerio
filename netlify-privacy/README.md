# Netlify upload — Grocerio privacy + account deletion

Upload **this folder’s contents** (not the parent repo) to Netlify.

## Play Console URLs (after deploy)

Replace `YOUR_SITE` with your Netlify subdomain (or custom domain):

| Play / Supabase field | URL |
| --- | --- |
| **Privacy policy** | `https://YOUR_SITE.netlify.app/` |
| **Account deletion** | `https://YOUR_SITE.netlify.app/#account-deletion` |
| **Email confirmed (Supabase Site URL + Redirect URL)** | `https://YOUR_SITE.netlify.app/auth-confirmed.html` |

## Deploy (drag-and-drop)

1. Open [https://app.netlify.com/drop](https://app.netlify.com/drop) (signed in).
2. Drag the entire `netlify-privacy` folder onto the page.
3. Copy the live URL Netlify gives you.
4. Open `https://…/#account-deletion` and confirm the Account deletion section is visible.
5. Open `https://…/auth-confirmed.html` and confirm you see “Email verified”.
6. Paste privacy / deletion URLs into Play Console → App content.
7. In Supabase → Authentication → URL Configuration: set **Site URL** to
   `…/auth-confirmed.html`, add that URL plus `io.grocerio://login-callback/`
   under **Redirect URLs**, and rebuild the app with
   `AUTH_EMAIL_REDIRECT_URL` pointing at the same page.

## Deploy (CLI, optional)

```bash
cd netlify-privacy
npx netlify deploy --prod --dir=.
```

## Contents

| File | Role |
| --- | --- |
| `index.html` | Privacy policy + `#account-deletion` anchor |
| `auth-confirmed.html` | Post-confirm landing (“Email verified → return to app”) |
| `netlify.toml` | Publish root + security headers |
| `README.md` | This file |

Keep [`../PRIVACY.md`](../PRIVACY.md) in the repo as the editable source of truth.
When you change the policy, update **both** `PRIVACY.md` and `index.html`, then redeploy.
