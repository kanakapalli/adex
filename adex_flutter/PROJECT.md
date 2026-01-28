# Adex Flutter App

A cross-platform Flutter application for extracting product information from videos using AI-powered frame analysis.

## Overview

Adex is a video processing application that captures or uploads product videos, extracts key frames, and uses AI to read and structure product information such as nutrition facts, ingredients, and manufacturing details.

## Platform Support

| Platform | UI Mode | Video Input |
|----------|---------|-------------|
| iOS | Mobile | Camera capture |
| Android | Mobile | Camera capture |
| Web | Desktop | File picker |
| macOS | Desktop | File picker |
| Windows | Desktop | File picker |
| Linux | Desktop | File picker |

## Architecture

```
adex_flutter/
├── lib/
│   ├── main.dart                    # App entry point with platform detection
│   └── screens/
│       ├── main_navigation_screen.dart    # Desktop navigation (bottom nav)
│       ├── adex_service_screen.dart       # Desktop video processing
│       ├── adex_models_screen.dart        # Desktop results viewer
│       └── mobile/
│           └── adex_service_screen.dart   # Mobile single-screen app
```

## Features

### Mobile App (iOS/Android)

Single-screen experience with state-based navigation:

| State | Description |
|-------|-------------|
| `camera` | Full-screen camera preview with record controls |
| `preview` | Recorded video playback with process/retake options |
| `processing` | Progress indicator during server processing |
| `results` | Extracted frames, data, and JSON viewer |
| `history` | List of past processing results |

**Camera View Controls:**
- **Record button** (center) - Tap to start/stop video recording
- **Settings button** (left of record) - Opens configuration sheet
- **History button** (top right) - View past results

**Settings Sheet:**
- Main extraction prompt
- Video description
- Frame types to extract (comma-separated)
- Text extraction toggle
- Text extraction prompt
- Performance settings (concurrency, delay, retries)

### Desktop App (Web/macOS/Windows/Linux)

Two-tab navigation with responsive layout:

| Tab | Description |
|-----|-------------|
| Process | Upload video, configure prompts, view results |
| Models | Browse all processed videos and their data |

**Responsive Breakpoints:**
- `< 600px` - Compact (mobile-like)
- `600-840px` - Medium
- `840-1200px` - Expanded (side-by-side layout)
- `1200-1600px` - Large
- `> 1600px` - Extra large

## Configuration Options

### Extraction Prompts

| Field | Description | Default |
|-------|-------------|---------|
| User Prompt | What to extract from the video | Extract nutrition facts, ingredients... |
| Video Description | What the video contains | Video of packed food product... |
| Frame Types | Types of frames to extract | nutrition_facts, ingredients_list, product_front, product_back, barcode |
| Text Extraction Prompt | Detailed extraction instructions | Extract product info, nutrition facts... |

### Performance Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Concurrency | Parallel API calls | 5 |
| Delay (ms) | Delay between batches | 200 |
| Max Retries | Retries per API call | 5 |

## Dependencies

```yaml
dependencies:
  flutter: sdk
  adex_client: path (auto-generated Serverpod client)
  serverpod_flutter: 3.2.1
  serverpod_auth_idp_flutter: 3.2.1
  camera: ^0.11.0+2          # Mobile camera capture
  video_player: ^2.9.2       # Video playback
  file_picker: ^8.0.0        # Desktop file selection
```

## Setup

### 1. Install Dependencies

```bash
cd adex_flutter
flutter pub get
```

### 2. Configure Camera Permissions

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to record product videos</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record videos</string>
```

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="true"/>
```

### 3. Configure Server URL

Set via environment variable:
```bash
flutter run --dart-define=SERVER_URL=https://api.example.com/
```

Or update `assets/config.json`:
```json
{
  "serverUrl": "https://api.example.com/"
}
```

## Running the App

### Development

```bash
# Run on connected device/emulator
flutter run

# Run on specific device
flutter run -d <device_id>

# Run on Chrome (web)
flutter run -d chrome
```

### Build

```bash
# iOS
flutter build ios

# Android
flutter build apk

# Web (for Serverpod deployment)
flutter build web --base-href /app/ --wasm
rm -rf ../adex_server/web/app && mv build/web/ ../adex_server/web/app
```

## Data Flow

```
┌─────────────────┐
│  Camera/File    │
│    Capture      │
└────────┬────────┘
         │ Video bytes
         ▼
┌─────────────────┐
│  Serverpod      │
│    Client       │
└────────┬────────┘
         │ processVideo()
         ▼
┌─────────────────┐
│  Adex Server    │
│  (Processing)   │
└────────┬────────┘
         │ AdexModel
         ▼
┌─────────────────┐
│  Results View   │
│  - Frames       │
│  - Data         │
│  - JSON         │
└─────────────────┘
```

## API Integration

The app communicates with the Serverpod backend via the auto-generated `adex_client`:

```dart
// Process a video
final result = await client.adexService.processVideo(
  byteData,                          // Video bytes
  userPrompt,                        // Main extraction prompt
  whatDoesThisVideoContain: ...,     // Video description
  suggestFramesToExtract: [...],     // Frame types
  extractToText: true,               // Enable text extraction
  extractedDataInformationPrompt: ..., // Text extraction prompt
  concurrency: 5,                    // Parallel calls
  delayBetweenBatchesMs: 200,        // Batch delay
  maxRetries: 5,                     // Retry count
);

// Get all processed models
final models = await client.adexService.getAllAdexModels();
```

## Response Model

```dart
class AdexModel {
  int? id;
  String processingId;
  String userPrompt;
  String videoUrl;
  String? whatDoesThisVideoContain;
  String? suggestFramesToExtract;
  bool extractToText;
  String? extractedDataInformationPrompt;
  String? extractedFrames;    // JSON array of frame data
  String? extractedText;      // JSON object of extracted text
  String status;              // pending, processing, completed, failed
  String? errorMessage;
  DateTime createdAt;
  DateTime? completedAt;
}
```

## Extracted Frames Format

```json
[
  {
    "frameType": "nutrition_facts",
    "description": "Nutrition information panel",
    "extractedFrameUrls": [
      "/uploads/extracted_frames/1/nutrition_facts_1.png",
      "/uploads/extracted_frames/1/nutrition_facts_2.png"
    ],
    "extractedFrameTimestamps": [2.5, 3.1]
  }
]
```

## Extracted Text Format

```json
{
  "product_information": {
    "brand": "Example Brand",
    "name": "Product Name",
    "net_weight": "500g"
  },
  "nutrition_facts": {
    "serving_size": "100g",
    "calories": "250",
    "total_fat": "10g"
  },
  "ingredients": ["Wheat flour", "Sugar", "Salt"],
  "allergens": ["Contains wheat", "May contain nuts"]
}
```

## UI Components

### Mobile

| Component | Description |
|-----------|-------------|
| `CameraPreview` | Live camera feed |
| `VideoPlayer` | Recorded/processed video playback |
| `DraggableScrollableSheet` | Settings bottom sheet |
| `ExpansionTile` | Collapsible data sections |

### Desktop

| Component | Description |
|-----------|-------------|
| `NavigationRail` | Side navigation (wide screens) |
| `NavigationBar` | Bottom navigation (narrow screens) |
| `FilePicker` | Video file selection |
| `VideoPlayer` | Video playback with timestamp markers |

## Error Handling

- Camera initialization errors displayed on camera view
- Processing errors shown in preview/results view
- Network errors with retry option
- Rate limiting handled with configurable delays

## Future Enhancements

- [ ] Offline mode with local processing queue
- [ ] Multiple video batch processing
- [ ] Export results to CSV/PDF
- [ ] Share results via native share sheet
- [ ] Real-time processing progress from server
- [ ] Camera flash and zoom controls
- [ ] Front/back camera toggle
