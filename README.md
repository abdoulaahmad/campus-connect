# CampusConnect AUS

**Group 11 | CAM-AUS-11 | Lead: Abdullahi Abba Ahmad | FCP/CIT/22/1000**

Unified Intelligent Mobile Campus Platform — Flutter (Android + iOS).

---

## Running the App

### Environment Overview

| `ENV` value | Repository | Data source |
|---|---|---|
| `dev` _(default)_ | `Mockoon*Repository` | Local Mockoon server |
| `prod` | `Supabase*Repository` | Live Supabase cloud |
| `test` | `Mock*Repository` | In-memory (no network) |

---

### On an Android Emulator (ENV=dev)

The emulator maps `10.0.2.2` to your machine's `localhost`, so Mockoon works out of the box:

```bash
# Start Mockoon on your machine first (port 3000), then:
flutter run --dart-define=ENV=dev
```

---

### Starting the Mockoon mock server (ENV=dev)

An importable Mockoon environment is provided at [`mockoon/campus_connect_mockoon.json`](mockoon/campus_connect_mockoon.json). It serves `/auth/login`, `/auth/register`, `/auth/me`, `/listings`, `/chats`, and `/chats/unread`.

**Option 1 — Mockoon CLI (no install, needs Node.js):**
```bash
npx -y @mockoon/cli@latest start --data ./mockoon/campus_connect_mockoon.json --port 3000
```
This binds to all network interfaces by default, so a physical phone on the same Wi-Fi can reach it.

**Option 2 — Mockoon desktop app:**
1. Install from https://mockoon.com/download/ (or `winget`/Microsoft Store)
2. File → Open environment → select `mockoon/campus_connect_mockoon.json`
3. In environment settings, leave **Hostname** empty (listens on all interfaces)
4. Click the green start button

**Mock credentials:**
| Email | Returns |
|-------|---------|
| `admin@university.edu` | Admin user |
| any other email | Student user (default) |

Verify it works:
```bash
curl -X POST http://localhost:3000/api/v2/aus/auth/login -H "Content-Type: application/json" -d "{\"email\":\"student@university.edu\",\"password\":\"student123\"}"
```

---

### On a Physical Phone (ENV=dev) ⚠️

`10.0.2.2` does **not** work on a real device. You must pass your machine's LAN IP instead.

**Step 1 — Find your machine's LAN IP:**
```bash
# Windows
ipconfig
# Look for "IPv4 Address" under your Wi-Fi adapter, e.g. 192.168.1.105
```

**Step 2 — Make sure your phone and PC are on the same Wi-Fi network.**

**Step 3 — Start Mockoon** on port 3000.

**Step 4 — Run with your LAN IP:**
```bash
flutter run --dart-define=ENV=dev --dart-define=API_URL=http://192.168.1.105:3000/api/v2/aus/
```
_(Replace `192.168.1.105` with your actual LAN IP.)_

---

### No network / Quick test (ENV=test)

Uses pure in-memory mocks. Works on any device with no server needed:

```bash
flutter run --dart-define=ENV=test
```

**Test credentials:**
| Email | Password | Role |
|-------|----------|------|
| `student@university.edu` | `student123` | Student |
| `admin@university.edu` | `admin123` | Admin |

---

### Production (ENV=prod) — Supabase

**No credit card required.** Supabase free tier is enough for a university campus app.

#### Step 1 — Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → Sign up (email only, no card)
2. New project → give it a name, set a strong DB password, pick region (`West EU` or `US East`)
3. Wait ~2 minutes for provisioning

#### Step 2 — Run the schema

1. Dashboard → SQL Editor → New Query
2. Paste the full contents of [`supabase/schema.sql`](supabase/schema.sql)
3. Click **Run** — this creates all tables, RLS policies, indexes, and RPC functions

#### Step 3 — Enable Realtime

Dashboard → Database → Replication → enable for these tables:
- `chats`
- `messages`
- `typing_indicators`
- `listings`
- `sos_alerts`

#### Step 4 — Get your credentials

Dashboard → Project Settings → API:
- **Project URL** — looks like `https://xxxxxxxxxxxx.supabase.co`
- **anon public key** — starts with `eyJh...`

#### Step 5 — Run the app

```bash
flutter run \
  --dart-define=ENV=prod \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJh...
```

For a release APK:
```bash
flutter build apk \
  --dart-define=ENV=prod \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJh... \
  --release
```

> The credentials are baked into the binary at build time and never stored in source code.

---

## Android Permissions

The following permissions are declared in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml):

| Permission | Required by |
|---|---|
| `INTERNET` | All network calls (Mockoon, Supabase) |
| `ACCESS_NETWORK_STATE` | Connectivity detection |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | `local_auth` biometric login |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | Campus map (`geolocator`) |

`android:usesCleartextTraffic="true"` is set to allow plain `http://` traffic to the local Mockoon dev server on Android 9+.

---

## Architecture

Clean Architecture + Repository Pattern + Riverpod DI. See [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) for full details.
