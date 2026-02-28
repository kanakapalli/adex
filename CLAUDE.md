# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Serverpod project with three packages:
- **adex_server**: Dart backend server with PostgreSQL and Redis
- **adex_client**: Auto-generated client library for server communication
- **adex_flutter**: Flutter mobile/web frontend

Serverpod version: 3.2.3 | Dart SDK: ^3.8.0 | Flutter: ^3.32.0

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

### Database Migrations
```bash
# Create a new migration (use --force for destructive schema changes)
cd adex_server && serverpod create-migration
cd adex_server && serverpod create-migration --force

# Apply pending migrations
cd adex_server && dart bin/main.dart --apply-migrations
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
- The `Client` class provides typed access to all endpoints (e.g., `client.adexService.processVideoFromUrl(...)`)

### Flutter Structure (adex_flutter)
- Uses global `Client` instance from `main.dart` for server communication
- Server URL configured via `--dart-define=SERVER_URL=...` or `assets/config.json`

### Model Definition Pattern
Models are defined in `.spy.yaml` files (e.g., `adex_model.spy.yaml`):
```yaml
class: ModelName
table: table_name
fields:
  fieldName: Type
```
Run `serverpod generate` after changes to update generated code in both server and client.

### Endpoint Pattern
Endpoints extend `Endpoint` class. Method parameters include `Session session` as first argument:
```dart
class AdexServiceEndpoint extends Endpoint {
  Future<AdexModel> processVideoFromUrl(Session session, String videoUrl, ...) async { ... }
}
```
Accessed from client without `Endpoint` suffix: `client.adexService.processVideoFromUrl(...)`

## Endpoints Inventory

### `adex_service` (`lib/src/adex_service/adex_service_endpoint.dart`)
Main video processing pipeline endpoint.
- `processVideoFromUrl(session, videoUrl, processingId, userPrompt, ...)` — Full async pipeline: extract frames → embed → classify → RAG search → OCR
- `getProcessingStatus(session, processingId)` — Poll job status
- `deleteProcessingJob(session, processingId)` — Delete job and all associated data
- `generateUploadUrl(session, fileName)` — Generate S3 presigned POST URL for direct client upload

### `auth` (via `serverpod_auth_idp_server`)
JWT-based email authentication. Registered automatically by `AuthConfig` in `server.dart`.
- Email sign-up / sign-in
- Email verification codes (logged to console in dev)
- Password reset via Gmail SMTP

## AI Stack

### Amazon Nova 2 Multimodal Embeddings
- **Model ID**: `amazon.nova-2-multimodal-embeddings-v1:0`
- **Dimensions**: 1024
- **Service**: AWS Bedrock Runtime (`bedrock-runtime.us-east-1.amazonaws.com`)
- **Image embedding**: `taskType: SINGLE_EMBEDDING`, `embeddingPurpose: GENERIC_INDEX`
- **Text embedding**: `taskType: SINGLE_EMBEDDING`, `embeddingPurpose: GENERIC_RETRIEVAL`
- **Schema version**: `nova-multimodal-embed-v1`

### Amazon Nova 2 Lite (Text Generation / OCR)
- **Model ID**: `us.amazon.nova-2-lite-v1:0` (US cross-region inference prefix required)
- **Service**: AWS Bedrock Runtime
- **Used for**: Frame type classification (text) and multimodal OCR (images + text)
- **Schema version**: `messages-v1`
- **Response path**: `result['output']['message']['content'][0]['text']`

### SigV4 Signing (AWS Auth)
All Bedrock calls are signed using AWS SigV4:
- Package: `amazon_cognito_identity_dart_2` (`SigV4` class) + `crypto` (`sha256`)
- Credentials from `passwords.yaml`: `AWSAccessKeyId`, `AWSSecretKey`
- Service name: `bedrock`, region: `us-east-1`
- **Critical**: Build URL with literal `:` in model ID (valid RFC 3986). Apply `_sigV4EncodePath()` only in the canonical request string to percent-encode `:` → `%3A`. Never use `Uri.encodeComponent` on the model ID — causes double-encoding bug.

## External Integrations

| Service | Purpose | Config key |
|---------|---------|------------|
| **AWS S3** (`eu-north-1`) | Video and frame storage | `AWSAccessKeyId`, `AWSSecretKey`, bucket in `config/` |
| **AWS Bedrock Runtime** (`us-east-1`) | Nova embeddings + Nova 2 Lite inference | `AWSAccessKeyId`, `AWSSecretKey` |
| **Gmail SMTP** | Email verification + password reset | `gmailAppPassword` in `passwords.yaml` |
| **FFmpeg** (OS-level) | Frame extraction at 2 FPS | Must be installed on server host |
| **PostgreSQL + pgvector** | Vector storage and cosine similarity search | `docker-compose.yml` |
| **Redis** | Session caching | `docker-compose.yml` |

## Authentication
Uses JWT-based auth with email identity provider (`serverpod_auth_idp`). Auth is initialized in `lib/server.dart`. Verification codes are logged to console in development. Password reset emails sent via Gmail SMTP (`mailer` package).

## Database
- PostgreSQL with pgvector extension
- Development DB on port 8090, test DB on port 9090
- Redis for caching on ports 8091 (dev) / 9091 (test)
- Migrations stored in `adex_server/migrations/`
- `video_frame_embeddings` table uses `Vector(1024)` with IVFFlat cosine index
- Vector dimension changes require drop + recreate (pgvector does not support `ALTER COLUMN` for dimension changes)

## Key Files Reference

| File | Purpose |
|------|---------|
| `adex_server/lib/server.dart` | Server init, auth, web routes, S3 setup |
| `adex_server/lib/src/adex_service/adex_service_endpoint.dart` | Main AI pipeline |
| `adex_server/lib/src/adex_service/adex_model.spy.yaml` | Job model definition |
| `adex_server/lib/src/videoExtractions/video_frame_embedding.spy.yaml` | Embedding model (Vector 1024) |
| `adex_server/lib/src/upload/s3_upload_helper.dart` | S3 upload with patched SigV4 |
| `adex_server/config/passwords.yaml` | Secrets (not committed) |
| `adex_flutter/assets/config.json` | Server URL for Flutter app |
