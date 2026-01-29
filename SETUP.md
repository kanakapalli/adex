# Setup and Run Guide

Instructions for setting up and running the ADEX project locally.

---

## Prerequisites

Install the following before starting:

| Tool | Version | Purpose |
|------|---------|---------|
| [Dart SDK](https://dart.dev/get-dart) | ^3.8.0 | Server runtime |
| [Flutter SDK](https://flutter.dev/docs/get-started/install) | ^3.32.0 | Frontend framework |
| [Docker](https://docs.docker.com/get-docker/) | Latest | PostgreSQL and Redis containers |
| [FFmpeg](https://ffmpeg.org/download.html) | Latest | Video frame extraction |
| [Serverpod CLI](https://docs.serverpod.dev/) | 3.2.x | Code generation |

### Install Serverpod CLI

```bash
dart pub global activate serverpod_cli
```

### Verify installations

```bash
dart --version
flutter --version
docker --version
ffmpeg -version
serverpod version
```

---

## Configuration

### 1. Server passwords

Create or update the passwords file at `adex_server/config/passwords.yaml` with your credentials:

```yaml
development:
  database: '<your-database-password>'
  redis: '<your-redis-password>'
  serviceSecret: '<your-service-secret>'
```

### 2. External service credentials

The server requires credentials for the following services. These are configured in `adex_server/config/passwords.yaml` and referenced by the server code:

- **AWS S3** — For video and frame file storage
- **Google Cloud (Vertex AI / Gemini)** — For embeddings and text extraction
- **Gmail SMTP** — For email verification (optional in development — verification codes are logged to console)

### 3. Flutter server URL

The Flutter app connects to the server via a URL configured in one of two ways:

**Option A — Build flag:**
```bash
flutter run --dart-define=SERVER_URL=http://localhost:8080
```

**Option B — Config file:**
Edit `adex_flutter/assets/config.json`:
```json
{
  "serverUrl": "http://localhost:8080"
}
```

---

## Running the Project

### Step 1: Start the database and cache

```bash
cd adex_server
docker compose up --build --detach
```

This starts:
- **PostgreSQL** on port `8090` (with pgvector extension)
- **Redis** on port `8091`

### Step 2: Run code generation (if needed)

Run this after modifying any `.spy.yaml` model files or endpoint signatures:

```bash
cd adex_server
serverpod generate
```

### Step 3: Start the server

```bash
cd adex_server
dart bin/main.dart --apply-migrations
```

The `--apply-migrations` flag ensures database schema is up to date. The server starts on `http://localhost:8080` by default.

### Step 4: Run the Flutter app

**Mobile (iOS/Android):**
```bash
cd adex_flutter
flutter run
```

**Web:**
```bash
cd adex_flutter
flutter run -d chrome
```

**macOS:**
```bash
cd adex_flutter
flutter run -d macos
```

---

## Building for Production

### Build Flutter web app and serve from Serverpod

```bash
cd adex_flutter
flutter build web --base-href /app/ --wasm
rm -rf ../adex_server/web/app && mv build/web/ ../adex_server/web/app
```

After this, the Flutter app is served at `http://<server-host>:8080/app/`.

### Build mobile

```bash
# Android
cd adex_flutter
flutter build apk

# iOS
cd adex_flutter
flutter build ios
```

---

## Running Tests

### Server tests

Requires the test database running (started by Docker Compose on port `9090`):

```bash
cd adex_server
dart test
```

Run a specific test:

```bash
cd adex_server
dart test test/integration/greeting_endpoint_test.dart
```

### Code analysis

```bash
# Server
cd adex_server
dart analyze

# Flutter
cd adex_flutter
flutter analyze
```

---

## Stopping Services

```bash
cd adex_server
docker compose stop
```

To remove containers and volumes entirely:

```bash
cd adex_server
docker compose down -v
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Server won't start | Ensure Docker containers are running: `docker compose ps` |
| Database connection refused | Check port `8090` is not in use: `lsof -i :8090` |
| FFmpeg not found | Install FFmpeg and ensure it's on your PATH |
| Code generation fails | Run `dart pub get` in `adex_server` first |
| Flutter can't connect to server | Verify `SERVER_URL` matches the running server address |
| Email verification not working | In development, check the server console for verification codes |

---

## Port Reference

| Service | Development Port | Test Port |
|---------|-----------------|-----------|
| Serverpod | 8080 | — |
| PostgreSQL | 8090 | 9090 |
| Redis | 8091 | 9091 |
