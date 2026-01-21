# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Serverpod project with three packages:
- **adex_server**: Dart backend server with PostgreSQL and Redis
- **adex_client**: Auto-generated client library for server communication
- **adex_flutter**: Flutter mobile/web frontend

Serverpod version: 3.2.1 | Dart SDK: ^3.8.0 | Flutter: ^3.32.0

## Common Commands

### Start Development Environment
```bash
# Start PostgreSQL and Redis (required before running server)
cd adex_server && docker compose up --build --detach

# Run the server with migrations
cd adex_server && dart bin/main.dart --apply-migrations

# Stop services when done
cd adex_server && docker compose stop
```

### Code Generation
After modifying endpoints or model YAML files:
```bash
cd adex_server && serverpod generate
```

### Run Flutter App
```bash
cd adex_flutter && flutter run
```

### Build Flutter Web App for Server
```bash
cd adex_flutter && flutter build web --base-href /app/ --wasm
rm -rf ../adex_server/web/app && mv build/web/ ../adex_server/web/app
```

### Run Tests
```bash
# Server tests (requires test database running)
cd adex_server && dart test

# Run specific test file
cd adex_server && dart test test/integration/greeting_endpoint_test.dart
```

### Analyze Code
```bash
cd adex_server && dart analyze
cd adex_flutter && flutter analyze
```

## Architecture

### Server Structure (adex_server)
- `lib/server.dart` - Server initialization, auth setup, and web route configuration
- `lib/src/<feature>/` - Feature directories containing endpoints and models
- `lib/src/<feature>/*.spy.yaml` - Model definitions (Serverpod protocol YAML)
- `lib/src/<feature>/*_endpoint.dart` - API endpoint classes
- `lib/src/generated/` - Auto-generated protocol and endpoint code (do not edit)
- `config/` - Environment configs: development.yaml, test.yaml, production.yaml, passwords.yaml

### Client Structure (adex_client)
- `lib/src/protocol/` - Auto-generated client code from server definitions
- The `Client` class provides typed access to all endpoints (e.g., `client.greeting.hello()`)

### Flutter Structure (adex_flutter)
- Uses global `Client` instance from `main.dart` for server communication
- Server URL configured via `--dart-define=SERVER_URL=...` or `assets/config.json`

### Model Definition Pattern
Models are defined in `.spy.yaml` files (e.g., `greeting.spy.yaml`):
```yaml
class: ModelName
fields:
  fieldName: Type
```
Run `serverpod generate` after changes to update generated code in both server and client.

### Endpoint Pattern
Endpoints extend `Endpoint` class. Method parameters include `Session session` as first argument:
```dart
class GreetingEndpoint extends Endpoint {
  Future<Greeting> hello(Session session, String name) async { ... }
}
```
Accessed from client without `Endpoint` suffix: `client.greeting.hello(name)`

## Authentication
Uses JWT-based auth with email identity provider (`serverpod_auth_idp`). Auth is initialized in `lib/server.dart`. Verification codes are logged to console in development (implement email sending for production).

## Database
- PostgreSQL with pgvector extension
- Development DB on port 8090, test DB on port 9090
- Redis for caching on ports 8091 (dev) / 9091 (test)
- Migrations stored in `adex_server/migrations/`
