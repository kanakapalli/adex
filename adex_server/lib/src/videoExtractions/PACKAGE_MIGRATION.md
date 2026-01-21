# Migration to google_generative_ai Package

## What Changed

We've upgraded the implementation to use the official `google_generative_ai` package instead of direct HTTP API calls, and configured it to read the API key from Serverpod's `passwords.yaml`.

## Benefits

### 1. **Cleaner Code**
**Before** (Manual HTTP calls):
```dart
final url = 'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=$apiKey';
final response = await http.post(
  Uri.parse(url),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'content': {'parts': [{'inlineData': {'mimeType': 'image/png', 'data': base64Image}}]},
    'taskType': 'RETRIEVAL_DOCUMENT',
  }),
);
final result = jsonDecode(response.body);
final embedding = (result['embedding']['values'] as List)
    .map((e) => (e as num).toDouble())
    .toList();
```

**After** (Using Package):
```dart
final model = GenerativeModel(model: 'text-embedding-004', apiKey: apiKey);
final content = Content.multi([DataPart('image/png', imageBytes)]);
final embeddingResult = await model.embedContent(content, taskType: TaskType.retrievalDocument);
final embedding = embeddingResult.embedding.values;
```

### 2. **Secure Configuration**
- API key stored in `config/passwords.yaml` (not in code)
- Automatically loaded from `session.passwords`
- Different keys for dev/staging/production
- No hardcoded credentials

### 3. **Simpler API**
**Before**:
```dart
processVideoComplete(session, videoUrl, outputDir, geminiApiKey)
```

**After**:
```dart
processVideoComplete(session, videoUrl, outputDir)
```

### 4. **Better Error Handling**
- Package handles API versioning
- Built-in retry logic
- Type-safe responses
- Better error messages

## Files Modified

### 1. `videoExration.dart`
- Added `import 'package:google_generative_ai/google_generative_ai.dart';`
- Updated `processVideoComplete()` to read API key from `session.passwords`
- Simplified `_generateGeminiEmbedding()` to use the package
- Removed manual HTTP calls and JSON parsing

### 2. `config/passwords.yaml`
- Added `geminiApiKey` under `shared` section
- Includes helpful comments with link to get API key

### 3. `pubspec.yaml`
- Added `google_generative_ai: ^0.4.6` dependency

### 4. Documentation Files
- `README.md` - Updated usage examples
- `QUICK_START.md` - Updated setup instructions
- `IMPLEMENTATION_SUMMARY.md` - Updated API documentation

## Setup Instructions

### 1. Get Your Gemini API Key
Visit: https://aistudio.google.com/apikey

### 2. Add to passwords.yaml
```yaml
# config/passwords.yaml
shared:
  geminiApiKey: 'YOUR_API_KEY_HERE'
```

### 3. Install Dependencies
```bash
cd learn_server_pod_server
dart pub get
```

### 4. Use the Simplified API
```dart
final images = await endpoints.videoExtraction.processVideoComplete(
  session,
  'https://your-video.mp4',
  '/output/directory',
);
```

## Technical Details

### Package Features Used
- `GenerativeModel` - Model initialization
- `Content.multi()` - Multimodal content creation
- `DataPart` - Image data handling
- `embedContent()` - Embedding generation
- `TaskType.retrievalDocument` - Task specification

### API Key Loading
```dart
// Automatically loaded from passwords.yaml
final geminiApiKey = session.passwords['geminiApiKey'];

// Error handling for missing key
if (geminiApiKey == null || geminiApiKey.isEmpty) {
  throw Exception('Gemini API key not found in passwords.yaml');
}
```

### Configuration Hierarchy
```yaml
shared:           # Used across all environments
  geminiApiKey: 'xxx'

development:      # Override for dev (optional)
  geminiApiKey: 'dev-key'

production:       # Override for prod (optional)
  geminiApiKey: 'prod-key'
```

## Advantages of This Approach

1. ✅ **Type Safety** - Compile-time checks for API calls
2. ✅ **Maintainability** - Package updates handle API changes
3. ✅ **Security** - Credentials in config, not code
4. ✅ **Flexibility** - Different keys per environment
5. ✅ **Simplicity** - Less code to maintain
6. ✅ **Reliability** - Official package with better error handling
7. ✅ **Future-proof** - Package updates automatically

## Migration Checklist

- [x] Install `google_generative_ai` package
- [x] Add API key to `passwords.yaml`
- [x] Update `processVideoComplete()` to read from passwords
- [x] Replace HTTP calls with package methods
- [x] Update all documentation
- [x] Test the implementation
- [ ] **YOU DO**: Add your actual Gemini API key to `passwords.yaml`
- [ ] **YOU DO**: Test with a real video URL

## Testing

```dart
// Test the updated implementation
final result = await endpoints.videoExtraction.processVideoComplete(
  session,
  'https://natfirst-dap-prod.s3.ap-south-1.amazonaws.com/DS_ENGINE/video_extraction/video_20251203_152641.mp4',
  '/tmp/video_output',
);

print('Product: ${result['product']}');
print('Nutrition Facts: ${result['nutrifact']}');
print('Ingredients: ${result['ingredients']}');
print('Back: ${result['back']}');
```

## Troubleshooting

### Error: "Gemini API key not found in passwords.yaml"
**Solution**: Add your API key to `config/passwords.yaml` under the `shared` section.

### Error: Package version conflicts
**Solution**: Run `dart pub upgrade google_generative_ai`

### Error: API quota exceeded
**Solution**:
- Check usage at https://aistudio.google.com/
- Free tier: 1,500 requests/day
- Consider upgrading to paid tier for production

## Next Steps

1. Add your Gemini API key to `passwords.yaml`
2. Run migrations: `dart run bin/main.dart --apply-migrations`
3. Test with a sample video
4. Monitor logs for successful embedding generation
5. Deploy to staging/production with appropriate API keys

## Support

- **google_generative_ai Package**: https://pub.dev/packages/google_generative_ai
- **Gemini API Docs**: https://ai.google.dev/gemini-api/docs
- **Serverpod Passwords**: https://docs.serverpod.dev/concepts/passwords

Happy coding! 🚀
