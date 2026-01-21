# Video Frame Extraction and Analysis System

This system extracts frames from videos, generates embeddings using Vertex AI multimodalembedding@002, and uses RAG (Retrieval-Augmented Generation) to classify and extract product-related images.

## Features

- Extracts 2 frames per second (start and middle of each second)
- Generates 1408-dimensional embeddings using **Vertex AI multimodalembedding@002**
- Stores frame embeddings in PostgreSQL with pgvector for efficient similarity search
- Uses RAG-based retrieval to find and classify product images
- Automatically cleans up temporary frames and database entries
- Simple API with just one main method
- Credentials loaded from passwords.yaml

## Prerequisites

1. **FFmpeg and FFprobe** installed on the server
2. **PostgreSQL with pgvector extension** for vector similarity search
3. **Google Cloud Platform account** with Vertex AI API enabled
4. **GCP credentials** (project ID, location, access token)

## Database Setup

Run migrations to create the `video_frame_embeddings` table:

```bash
cd learn_server_pod_server
serverpod_cli create-migration
serverpod_cli migrate
```

Enable pgvector extension in PostgreSQL:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

## Usage

### Simple One-Method API

Use the `processVideoComplete` method - that's all you need!

```dart
final result = await endpoints.videoExtraction.processVideoComplete(
  session,
  'https://example.com/video.mp4',
  '/path/to/output/directory',
);

// Result contains paths to extracted images:
// {
//   'product': '/path/to/output/product/product_xxx.png',
//   'nutrifact': '/path/to/output/nutrifact/nutrifact_xxx.png',
//   'ingredients': '/path/to/output/ingredients/ingredients_xxx.png',
//   'back': '/path/to/output/back/back_xxx.png',
// }
```

**Note**: Vertex AI credentials are automatically loaded from `config/passwords.yaml`

The method handles everything:
- Downloads video
- Extracts 2 frames per second
- Generates embeddings with Vertex AI multimodalembedding@002
- Saves to database
- Classifies frames
- Saves final images
- Cleans up temporary data

## How It Works

### 1. Frame Extraction

- Downloads video from URL
- Uses FFmpeg to extract 2 frames per second
- Frames are saved as PNG files in temporary directory

### 2. Embedding Generation

- Each frame is sent to **Vertex AI multimodalembedding@002**
- Returns 1408-dimensional embedding vector
- Embeddings capture semantic content of the image
- Enterprise-grade quality and accuracy

### 3. Database Storage

- Frames and embeddings are stored in `video_frame_embeddings` table
- IVFFlat index enables fast cosine similarity search
- Includes metadata like timestamp, frame number, file path

### 4. RAG-Based Retrieval

- Uses heuristics based on video timeline:
  - **Product**: First 20% of video
  - **Nutrition Facts**: 40-60% of video
  - **Ingredients**: 30-50% of video
  - **Back of Package**: 60-80% of video

- Can be enhanced with actual vector similarity search using text queries

### 5. Classification & Saving

- Selected frames are copied to organized output directories
- Directory structure:
  ```
  output/
  ├── product/
  ├── nutrifact/
  ├── ingredients/
  └── back/
  ```

### 6. Cleanup

- Deletes temporary frame files
- Removes database entries for processed video
- Keeps only the final classified images

## API Parameters

### Required Parameters

- **videoUrl**: URL of the video file to process (must be accessible)
- **outputDir**: Directory path where classified images will be saved

### Setting Up Vertex AI Credentials

1. **Get your GCP credentials**:
   - Project ID: From Google Cloud Console
   - Location: Region (e.g., `us-central1`, `europe-west1`)
   - Access Token: Run `gcloud auth print-access-token`

2. **Add to passwords.yaml**:
   ```yaml
   # config/passwords.yaml
   shared:
     vertexAI:
       projectId: 'YOUR_GCP_PROJECT_ID'
       location: 'us-central1'
       accessToken: 'YOUR_ACCESS_TOKEN'
   ```

3. **Enable Vertex AI API**:
   ```bash
   gcloud services enable aiplatform.googleapis.com
   ```

4. **That's it!** Credentials are automatically loaded when you call the method.

**Note**: Access tokens expire after 1 hour. For production, use service account keys.

## Advanced: Vector Similarity Search

For production use, implement true vector similarity search:

```dart
// Generate text embedding for query
final queryEmbedding = await _generateTextEmbedding(
  'nutrition facts table',
  gcpProjectId,
  gcpLocation,
  gcpAccessToken,
);

// Find similar frames using cosine distance
final similarFrames = await session.db.query(
  'SELECT *, 1 - (embedding <=> @queryEmbedding) AS similarity '
  'FROM video_frame_embeddings '
  'WHERE video_url = @videoUrl '
  'ORDER BY embedding <=> @queryEmbedding '
  'LIMIT 5',
  variables: {
    'queryEmbedding': queryEmbedding,
    'videoUrl': videoUrl,
  },
);
```

## Error Handling

All methods include comprehensive error handling:
- Video download failures
- FFmpeg errors
- API failures (Vertex AI)
- Database errors
- File I/O errors

Check server logs for detailed error messages.

## Performance Considerations

- **Video Size**: Larger videos take longer to process (2 frames/second)
- **API Costs**: Each frame requires 1 Vertex AI Vision API call
- **Storage**: Temporary frames stored until cleanup
- **Database**: Use IVFFlat index for >100k embeddings

## Limitations

- Current implementation uses timeline heuristics for classification
- For better accuracy, implement actual vector similarity search with text queries
- Requires external vision model API for classification verification

## Future Enhancements

1. Implement true RAG with text-to-image similarity search
2. Add support for multiple vision models (OpenAI CLIP, Claude Vision)
3. Batch processing for multiple videos
4. Support for different frame extraction rates
5. Add confidence scores for classifications
