# Quick Start Guide - Video Frame Extraction

## Code Organization

The implementation is well-organized with clear separation:

```
VideoExtractionEndpoint
├── PUBLIC API (Main Function)
│   └── processVideoComplete()          ← Call this method!
│
├── LEGACY API (Deprecated)
│   └── extractVideoFrames()            ← Backward compatibility
│
└── PRIVATE METHODS (Internal)
    ├── _processVideoWithEmbeddings()   ← Extracts frames, generates embeddings
    ├── _extractFrameAtTimestamp()      ← FFmpeg frame extraction
    ├── _generateGeminiEmbedding()      ← Gemini API integration
    ├── _extractProductImages()         ← RAG-based classification
    └── _cleanup()                      ← Cleanup temp files & DB
```

## 3-Step Setup

### 1. Add Vertex AI Credentials to passwords.yaml
```yaml
# config/passwords.yaml
shared:
  vertexAI:
    projectId: 'YOUR_GCP_PROJECT_ID'
    location: 'us-central1'
    accessToken: 'YOUR_ACCESS_TOKEN'
```

Get access token: `gcloud auth print-access-token`

### 2. Run Database Migration
```bash
cd learn_server_pod_server
dart run bin/main.dart --apply-migrations
```

### 3. Call the Method (No API key needed in code!)
```dart
final result = await endpoints.videoExtraction.processVideoComplete(
  session,
  'https://your-video-url.mp4',
  '/path/to/output',
);

// Done! Check result for image paths
print(result['product']);      // Product image path
print(result['nutrifact']);    // Nutrition facts path
print(result['ingredients']);  // Ingredients path
print(result['back']);         // Back of package path
```

**Note**: Vertex AI credentials are automatically loaded from `config/passwords.yaml`

## What Happens Under the Hood

```
1. Downloads video from URL
   ↓
2. Extracts 2 frames/second using FFmpeg
   ↓
3. For each frame:
   - Send to Gemini 2.5 Flash
   - Get 768-dim embedding
   - Save to PostgreSQL with vector index
   ↓
4. RAG Classification:
   - Query database for frames
   - Use timeline heuristics
   - Select best frames for each category
   ↓
5. Save classified images to folders:
   /output/product/
   /output/nutrifact/
   /output/ingredients/
   /output/back/
   ↓
6. Cleanup:
   - Delete temp frame files
   - Remove database entries
   ↓
7. Return paths to saved images
```

## Technology Stack

- **Frame Extraction**: FFmpeg + FFprobe
- **Embeddings**: Vertex AI multimodalembedding@002 (1408 dimensions)
- **Database**: PostgreSQL + pgvector
- **Vector Search**: IVFFlat index with cosine similarity
- **Language**: Dart (Serverpod)
- **Config Management**: Serverpod passwords.yaml

## Key Features

✅ **Simple API** - Just one method call
✅ **Automatic Cleanup** - No manual cleanup needed
✅ **Cost Effective** - Free tier: 1,500 requests/day
✅ **Fast** - Gemini 2.5 Flash is optimized for speed
✅ **Scalable** - Vector database for efficient search
✅ **Well Organized** - Clear public/private separation

## Pricing

**Vertex AI multimodalembedding@002**:
- **Free Tier**: $0 for first 1000 requests/month
- **Paid**: $0.00025 per image
- **60-second video**: 120 frames × $0.00025 = $0.03
- **1000 videos/day**: ~$30/day
- **Enterprise quality and reliability**

## Error Handling

All errors are logged to Serverpod logs:
- Video download failures
- FFmpeg errors
- Gemini API errors
- Database errors
- File I/O errors

Check server logs for detailed error messages.

## Advanced Usage

### Custom Frame Selection

For custom frame selection logic, modify `_extractProductImages()` method. Current implementation uses timeline heuristics:

- Product: 0-20% of video
- Nutrition Facts: 40-60% of video
- Ingredients: 30-50% of video
- Back: 60-80% of video

### Vector Similarity Search

For true RAG with semantic search, query embeddings using SQL:

```dart
// Find frames similar to a query
final sql = '''
  SELECT *, 1 - (embedding <=> $1::vector) AS similarity
  FROM video_frame_embeddings
  WHERE video_url = $2
  ORDER BY embedding <=> $1::vector
  LIMIT 5
''';

final results = await session.db.query(sql, [queryEmbedding, videoUrl]);
```

## Troubleshooting

### FFmpeg not found
```bash
# Windows
winget install FFmpeg

# Mac
brew install ffmpeg

# Linux
sudo apt install ffmpeg
```

### pgvector not installed
```sql
-- Connect to PostgreSQL
CREATE EXTENSION IF NOT EXISTS vector;
```

### Gemini API quota exceeded
- Check daily limit at: https://aistudio.google.com/
- Consider upgrading to paid tier
- Implement rate limiting in your code

## Support

- **Documentation**: See README.md and IMPLEMENTATION_SUMMARY.md
- **Serverpod Docs**: https://docs.serverpod.dev/
- **Gemini Docs**: https://ai.google.dev/gemini-api/docs/embeddings
- **pgvector**: https://github.com/pgvector/pgvector

## That's It!

You're ready to process videos and extract product images with AI-powered frame classification! 🚀
