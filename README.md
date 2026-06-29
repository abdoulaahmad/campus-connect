# CampusConnect AUS

**Group 11 | CAM-AUS-11 | Lead: Abdullahi Abba Ahmad | Matric: FCP/CIT/22/1000**

> Unified Intelligent Mobile Campus Platform for Abubakar Tafawa Balewa University (ATBU) / Federal University Dutse (FUD) — built with Flutter and Supabase.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Documentation](#project-documentation)
- [Getting Started](#getting-started)
- [Environment Modes](#environment-modes)
- [Running the App](#running-the-app)
- [Database Setup](#database-setup)
- [Testing](#testing)
- [Android Permissions](#android-permissions)
- [Project Structure](#project-structure)

---

## Overview

CampusConnect AUS is a unified mobile platform designed to streamline campus life for students and administrators at AUS. It consolidates key campus services — messaging, marketplace, map navigation, emergency alerts, scheduling, and admin management — into a single Flutter application backed by a real-time Supabase cloud database.

The app is built following Clean Architecture principles with a feature-first folder structure, Riverpod for state management and dependency injection, and a three-environment system (prod/dev/test) for flexible development and deployment.

---

## Features

| Feature | Description |
|---|---|
| **Authentication** | Email/password login, registration, biometric login (fingerprint/face), session persistence |
| **Messaging** | Real-time group and direct chats, message status (sent/delivered/read), 120s edit window, offline queue with sync |
| **Marketplace** | Buy/sell listings with category filters, QR code handshake for peer-to-peer transactions |
| **Campus Map** | Interactive OpenStreetMap with building polygons, tap-to-identify, location tracking |
| **SOS / Emergency** | Countdown alert with audio, GPS broadcast to all users, admin alert dashboard |
| **Schedule** | Bitmask-based weekly timetable, free-slot intersection across multiple schedules |
| **Notifications** | In-app notification feed with read/unread state |
| **Admin Dashboard** | Manage users, events, announcements, and SOS alerts |

---

## Architecture

**Pattern:** Clean Architecture + Repository Pattern + Riverpod DI

```
lib/
├── core/                    # Shared utilities, providers, services, router
│   ├── config/              # Environment, theme, app config
│   ├── database/            # SQLite (sqflite) local database
│   ├── network/             # Dio HTTP client
│   ├── providers/           # Core Riverpod providers (DI slots)
│   ├── router/              # GoRouter + auth guard
│   ├── services/            # Connectivity, QR, secure storage
│   └── utils/               # Polygon math, helpers
└── features/                # Feature-first modules
    ├── auth/
    ├── messaging/
    ├── marketplace/
    ├── map/
    ├── sos/
    ├── schedule/
    ├── notifications/
    ├── admin/
    └── home/
```

Each feature follows the layered pattern:

| Layer | Rule |
|---|---|
| `domain/` | Pure Dart only — entities, use cases, repository interfaces, failures |
| `data/` | Repository implementations — Supabase, Mockoon, in-memory mocks |
| `presentation/` | Screens, Riverpod notifiers/providers, widgets |

---

## Tech Stack

| Category | Package | Version |
|---|---|---|
| State / DI | `flutter_riverpod` | ^2.5.1 |
| Navigation | `go_router` | ^14.2.7 |
| Backend | `supabase_flutter` | ^2.5.6 |
| HTTP (dev) | `dio` | ^5.4.3 |
| Local DB | `sqflite` | ^2.4.3 |
| Biometric | `local_auth` | ^2.2.0 |
| Secure Storage | `flutter_secure_storage` | ^9.2.2 |
| Map | `flutter_map` + `latlong2` | ^8.3.0 / ^0.9.1 |
| Location | `geolocator` | ^13.0.4 |
| QR | `qr_flutter` + `mobile_scanner` | ^4.1.0 / ^5.1.1 |
| Audio | `audioplayers` | ^6.0.0 |
| Fonts | `google_fonts` | ^6.2.1 |
| UUID | `uuid` | ^4.4.0 |

---

## Project Documentation

The `docs/` folder contains the full project documentation suite produced during the development lifecycle:

| Document | Description |
|---|---|
| [`CampusConnect_AUS_Project_Overview_v1.docx`](docs/CampusConnect_AUS_Project_Overview_v1.docx) | High-level project summary — objectives, scope, stakeholders, deliverables, and timeline for all sprints |
| [`CampusConnect_AUS_Requirements_v1.1.docx`](docs/CampusConnect_AUS_Requirements_v1.1%20(2).docx) | Functional and non-functional requirements, user stories, acceptance criteria for all 8 features |
| [`CampusConnect_AUS_System_Architecture_v1.docx`](docs/CampusConnect_AUS_System_Architecture_v1.docx) | System architecture diagram, Clean Architecture layer breakdown, environment switching design, Riverpod DI wiring |
| [`CampusConnect_AUS_Database_Design_Final.docx`](docs/CampusConnect_AUS_Database_Design_Final.docx) | Full Supabase Postgres schema — all tables, columns, data types, RLS policies, indexes, and RPC functions |
| [`CampusConnect_AUS_API_Specification_Final.docx`](docs/CampusConnect_AUS_API_Specification_Final.docx) | REST API specification for the Mockoon dev environment — all endpoints, request/response schemas, error codes |
| [`CampusConnect_AUS_UI_UX_Design.docx`](docs/CampusConnect_AUS_UI_UX_Design.docx) | UI/UX design rationale — dark theme design system, screen layouts, navigation flow, accessibility considerations |

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.3.0 <4.0.0`
- Dart SDK `>=3.3.0 <4.0.0`
- Android SDK (API 24+)
- Java 17+

### Install dependencies

```bash
flutter pub get
```

---

## Environment Modes

The app supports three environments switched via `--dart-define=ENV=`:

| `ENV` | Repository suffix | Data source |
|---|---|---|
| `dev` _(default)_ | `Mockoon*Repository` | Local Mockoon server at `http://10.0.2.2:3000/api/v2/aus/` |
| `prod` | `Supabase*Repository` | Live Supabase cloud |
| `test` | `Mock*Repository` | Pure in-memory, no network |

---

## Running the App

### Production — Supabase (recommended for demo)

```bash
flutter run \
  --dart-define=ENV=prod \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJh...
```

### Development — Mockoon mock server

```bash
# Start Mockoon first (port 3000), then:
flutter run --dart-define=ENV=dev
```

For a physical device on the same Wi-Fi (replace with your LAN IP):
```bash
flutter run --dart-define=ENV=dev --dart-define=API_URL=http://192.168.1.x:3000/api/v2/aus/
```

### Test — in-memory mocks (no server needed)

```bash
flutter run --dart-define=ENV=test
```

**Test credentials:**

| Email | Password | Role |
|---|---|---|
| `student@university.edu` | `student123` | Student |
| `admin@university.edu` | `admin123` | Admin |

---

## Database Setup

### Step 1 — Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → New project
2. Wait ~2 minutes for provisioning

### Step 2 — Run the schema

Dashboard → SQL Editor → New Query → paste [`supabase/schema.sql`](supabase/schema.sql) → Run

This creates all tables (`users`, `chats`, `messages`, `typing_indicators`, `chat_members`, `listings`, `sos_alerts`), RLS policies, indexes, and RPC functions.

### Step 3 — Enable Realtime

Dashboard → Database → Replication → enable for:
`chats`, `messages`, `typing_indicators`, `listings`, `sos_alerts`

### Step 4 — Seed test data (optional)

Run in SQL Editor (replace `YOUR_USER_UUID` with your auth user ID):

```sql
INSERT INTO public.listings (id, seller_id, title, description, category, cost, image_url, status, is_flagged, created_at)
VALUES
  (gen_random_uuid(), 'YOUR_USER_UUID', 'Engineering Mathematics Textbook', 'Advanced Engineering Mathematics, 10th Edition.', 'books', 4500.00, 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=200', 'active', false, NOW()),
  (gen_random_uuid(), 'YOUR_USER_UUID', 'Dell Laptop Charger 65W', 'Original Dell USB-C charger, 65W.', 'electronics', 12000.00, 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=200', 'active', false, NOW());
```

---

## Testing

Run all unit and widget tests:

```bash
flutter test
```

Run with test environment:

```bash
flutter test --dart-define=ENV=test
```

**Test coverage:**

| Test file | What it covers |
|---|---|
| `test/widget_test.dart` | App renders without errors |
| `test/messaging_test.dart` | 120s edit window, send/read/sync queue |
| `test/marketplace_test.dart` | QR handshake, RLS, CRUD operations |
| `test/map_test.dart` | Building model serialization, mock repo |
| `test/building_search_test.dart` | Search, polygon ray-casting |
| `test/schedule_validation_test.dart` | Bitmask validation, schedule intersection |
| `test/sos_test.dart` | SOS notifier state transitions |
| `test/home_test.dart` | Home screen announcements/events loading |

---

## Android Permissions

| Permission | Required by |
|---|---|
| `INTERNET` | All network calls |
| `ACCESS_NETWORK_STATE` | Connectivity detection |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | Biometric login |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | Campus map |

`android:usesCleartextTraffic="true"` allows plain HTTP to the local Mockoon dev server on Android 9+.

---

## Project Structure

```
campus-connect/
├── lib/
│   ├── main.dart                  # Entry point, environment bootstrap
│   ├── app.dart                   # Root MaterialApp.router
│   ├── core/                      # Shared infrastructure
│   └── features/                  # Feature modules (auth, messaging, etc.)
├── test/                          # Unit + widget tests
├── supabase/
│   └── schema.sql                 # Full Postgres schema
├── docs/                          # Project documentation (6 documents)
├── assets/
│   └── config/config.json         # Campus code + API path validation
├── android/                       # Android platform config
├── ios/                           # iOS platform config
└── web/                           # Web platform config
```

---

> **CAM-AUS-11** · Group 11 · FCP/CIT/22/1000
