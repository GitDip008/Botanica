# 🌿 Botanica

> An AI-powered companion app for **Oulu Botanical Garden** — identify plants, chat with a botanist AI, follow guided trails, complete plant hunts, and more.

Selected as one of four winners of the **Growth Hack '26** program organized by **IKAPO** in collaboration with the **University of Oulu Botanical Garden**.

---

## 📱 Features

### 🤖 AI Plant Identification
Point your camera at any plant and get an instant identification. Uses **PlantNet** (free, plant-specialised) as the primary identifier, with a **Gemini** fallback when confidence is low or the photo isn't a plant. Description text is then enriched by **Groq (Llama 3.3 70B)** in your selected app language.

### 💬 Plant Chat (scope-locked)
After identifying a plant, ask anything about it — care, history, recipes, propagation. The AI is restricted to botanical topics, so off-topic questions are politely declined. Includes a "Start new conversation" option for free-form botanical Q&A.

### 📚 Chat History (Pin / Rename / Delete / Multi-select)
Every conversation is saved to Firestore and synced across devices. Long-press to enter multi-select, pin favourites to the top, rename chats, edit/copy/delete individual messages, or bulk-delete.

### 🔍 Plant Search
Type a plant name and the AI returns the species + a written description — also language-aware. Non-botanical queries (e.g. "chair", "table") are rejected with a friendly error.

### 🗺️ Interactive Garden Map
A live OpenStreetMap-based map with **verified GPS coordinates** for every section + facilities (parking, toilets, bus stop, ponds, gate). Tap a marker for info, search across sections, or get **in-app walking directions** powered by OpenRouteService — Google Maps fallback if routing is unavailable.

### 🥾 Self-Guided Trails
Three curated walking trails — Beginner, Explorer, Full Garden. Each stop shows a photo prompt, description, and live GPS distance.

### 🏆 Plant Hunt (Gamified)
A challenge for families and kids — find 3 specific plants using botanical clues, photograph each one, and have PlantNet validate the find. After 3 wrong attempts, a **"Tap to know the answer"** hint appears. Complete all three to earn the **Plant Detective badge**.

### 🎵 Soundscape Visualizer
Records ambient sound around you and renders it as a live flowing wave animation. Processes raw PCM audio at 44,100 samples/second at 60 FPS.

### 🌸 Bloom Calendar
AI-generated seasonal overview of what's flowering in each section, based on the current month.

### 📋 Visitor Reports
Spotted a damaged plant, pest, or safety issue? Submit a structured report with photo, GPS, and category. The report is saved locally **and** mirrored to Firestore so garden staff can see it from the admin panel. Pre-filled email to garden staff with one tap.

### 📅 Event Planner
Visitors can propose events at the garden — name, description, attendees, date, start/end time, space needs. The submission goes to Firestore and opens a pre-filled email to garden admin. Admins approve or reject from the Admin Panel.

### 💡 Did You Know?
AI-generated botanical facts on the home screen — random, language-aware, capped at 150 characters. Refresh on tap.

### 👤 User Accounts & Subscription
- **Firebase authentication** (email + password, Google sign-in, password reset)
- **Freemium tiers**: Free (10 AI chats/day, 1 hunt/day) · Premium (€2.99/mo or €19.99/yr · unlimited)
- **Admin tier**: bypasses all limits, accesses the Admin Panel
- Daily usage bars with live counter updates

### 🛡️ Admin Panel
Visible only to admin email allow-list users. Provides:
- **Stats**: total users · premium users · active today · chats today
- **Event approval** queue (approve/reject pending submissions)
- **Visitor reports** feed (synced from Firestore)

### ℹ️ About Us & Schedule
Tap the open/closed chip on the home screen for the garden schedule (greenhouses, outdoor, 2026 holiday hours). Full About Us page covers admission, parking, directions, photography rules, and links to Visit / Seed Exchange / Research / Botanical Museum pages.

### 🌍 Multi-Language Support
Full UI translation across **English · Suomi · Svenska**, plus language-aware AI responses for plant descriptions, search, bloom calendar, and chat.

### 🎨 Polished UX
- Adaptive launcher icon + dark-themed native splash screen
- Side drawer with 3-tier navigation
- Custom developer card with brand-icon social links (GitHub, LinkedIn, Portfolio, WhatsApp)

---

## 🛠️ Technologies

| Category | Stack |
|---|---|
| **Framework** | Flutter (Dart) — Android (iOS-ready) |
| **AI — Plant ID** | PlantNet API (free) · Google Gemini 2.5 Flash (fallback) |
| **AI — Chat / Description** | Groq (Llama 3.3 70B, free tier) · Gemini fallback |
| **Backend** | Firebase Auth · Cloud Firestore (EU region) |
| **Map** | flutter_map + OpenStreetMap tiles · geolocator (GPS) |
| **Walking routes** | OpenRouteService (free tier, 2 000 req/day) |
| **Image references** | Wikipedia REST API (free) |
| **Audio** | record (PCM stream) for live soundscape |
| **State management** | Provider |
| **Markdown rendering** | flutter_markdown (chat bubbles) |
| **Brand icons** | font_awesome_flutter |
| **Launcher / splash** | flutter_launcher_icons · flutter_native_splash |
| **Localisation** | Custom in-memory i18n (EN / FI / SV) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.11.5`
- Android device or emulator (API 23+)
- A Firebase project (free tier)
- API keys: **Gemini**, **Groq**, **PlantNet**, **OpenRouteService**

### Setup (after cloning)

1. **Clone the repository**
   ```bash
   git clone https://github.com/GitDip008/Botanica.git
   cd Botanica
   ```

2. **Configure your API keys**
   ```bash
   cp lib/config/api_config.example.dart lib/config/api_config.dart
   ```
   Open `lib/config/api_config.dart` and fill in your keys.

3. **Configure Firebase** — regenerates the gitignored Firebase files
   ```bash
   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
   ```
   This creates:
   - `lib/firebase_options.dart`
   - `android/app/google-services.json`

4. **Install dependencies & run**
   ```bash
   flutter pub get
   flutter run
   ```

> Enable **Email/Password** and **Google** sign-in in the Firebase Console, and add your debug-keystore SHA-1 fingerprint to your Android app config so Google sign-in works.

---

## 📂 Project Structure

```
lib/
├── config/
│   ├── api_config.dart          # API keys (git-ignored)
│   └── api_config.example.dart  # Template
├── data/
│   └── garden_sections.dart     # Garden sections + facilities with GPS
├── i18n/
│   └── app_strings.dart         # EN / FI / SV translations
├── models/
│   ├── plant_info.dart
│   ├── chat_session.dart
│   ├── event_request.dart
│   └── user_model.dart
├── screens/
│   ├── auth/                    # Login, signup, auth gate
│   ├── profile/                 # Profile + usage bars
│   ├── subscription/            # Paywall
│   ├── home_screen.dart
│   ├── camera_screen.dart
│   ├── map_screen.dart
│   ├── trail_screen.dart
│   ├── plant_hunt_screen.dart
│   ├── soundscape_screen.dart
│   ├── bloom_screen.dart
│   ├── search_screen.dart
│   ├── report_screen.dart
│   ├── chat_history_screen.dart
│   ├── chat_continuation_screen.dart
│   ├── event_request_screen.dart
│   ├── admin_panel_screen.dart
│   ├── about_us_screen.dart
│   ├── schedule_screen.dart
│   ├── settings_screen.dart
│   └── main_nav_screen.dart
├── services/
│   ├── auth_service.dart            # Abstract + mock
│   ├── firebase_auth_service.dart   # Production auth
│   ├── chat_service.dart            # Cloud → local → Gemini routing
│   ├── chat_history_service.dart    # Firestore chat persistence
│   ├── cloud_llm_service.dart       # Groq client
│   ├── gemini_service.dart          # Gemini client
│   ├── local_llm_service.dart       # On-device Gemma (optional)
│   ├── plant_identification_service.dart  # Orchestrator
│   ├── plantnet_service.dart
│   ├── wikipedia_image_service.dart
│   ├── routing_service.dart         # OpenRouteService walking routes
│   ├── event_service.dart
│   ├── report_service.dart
│   ├── garden_schedule.dart
│   ├── language_service.dart
│   └── user_state.dart
└── widgets/
    ├── app_drawer.dart
    ├── developed_by_card.dart
    ├── did_you_know_card.dart
    └── sound_visualizer.dart
```

---

## 🔑 API Key & Firebase Security

The following files are **never committed** to this repository:

- `lib/config/api_config.dart` — Gemini, Groq, PlantNet, OpenRouteService keys
- `lib/firebase_options.dart` — Firebase SDK config
- `android/app/google-services.json` — Firebase Android config
- `.env`, `*.keystore`, `*.jks`, `*.pem` — all environment files and signing keys

> ⚠️ For production deployment, API keys should be moved to a backend proxy (e.g. Firebase Cloud Functions, university server) to prevent extraction via APK decompilation.

---

## 📍 Garden Location

**Oulu Botanical Garden** (Oulun kasvitieteellinen puutarha)
Linnanmaa campus, University of Oulu
Kaitoväylä 5, 90570 Oulu, Finland
~ 65.0644° N, 25.4617° E

Section coordinates in `lib/data/garden_sections.dart` are verified against Google Maps. Facility coordinates (parking, toilets, bus, ponds) are best-effort estimates.

---

## 👨‍💻 Developer

**Shourove Sutradhar Dip**
- GitHub: [@GitDip008](https://github.com/GitDip008)
- LinkedIn: [shourov-dip](https://www.linkedin.com/in/shourov-dip/)
- Portfolio: [gitdip008.github.io](https://gitdip008.github.io/)
- WhatsApp: [+358 41 741 3188](https://wa.me/358417413188)

---

## 📄 License

Developed as part of the Growth Hack '26 program organized by IKAPO and in collaboration with University of Oulu Botanical Garden.
