BEGIN;

--
-- CREATE VECTOR EXTENSION IF AVAILABLE
--
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS vector';
  ELSE
    RAISE EXCEPTION 'Required extension "vector" is not available on this instance. Please install pgvector. For instructions, see https://docs.serverpod.dev/upgrading/upgrade-to-pgvector.';
  END IF;
END
$$;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "adex_models" (
    "id" bigserial PRIMARY KEY,
    "videoUrl" text NOT NULL,
    "processingId" text NOT NULL,
    "userPrompt" text NOT NULL,
    "whatDoesThisVideoContain" text,
    "suggestFramesToExtract" text,
    "extractToText" boolean NOT NULL DEFAULT false,
    "extractedDataInformationPrompt" text,
    "status" text NOT NULL DEFAULT 'pending'::text,
    "frameTypesJson" text,
    "extractedFrames" text,
    "extractedText" text,
    "errorMessage" text,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "processing_id_idx" ON "adex_models" USING btree ("processingId");
CREATE INDEX "status_idx" ON "adex_models" USING btree ("status");
CREATE INDEX "created_at_idx" ON "adex_models" USING btree ("createdAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "video_frame_embeddings" (
    "id" bigserial PRIMARY KEY,
    "adexModelId" bigint,
    "videoUrl" text NOT NULL,
    "processingId" text NOT NULL,
    "frameNumber" bigint NOT NULL,
    "timestamp" double precision NOT NULL,
    "framePath" text NOT NULL,
    "embedding" vector(1408) NOT NULL,
    "metadata" text,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX "adex_model_id_idx" ON "video_frame_embeddings" USING btree ("adexModelId");
CREATE INDEX "video_url_processing_id_idx" ON "video_frame_embeddings" USING btree ("videoUrl", "processingId");
CREATE INDEX "timestamp_idx" ON "video_frame_embeddings" USING btree ("timestamp");
CREATE INDEX "embedding_idx" ON "video_frame_embeddings" USING ivfflat ("embedding" vector_cosine_ops);


--
-- MIGRATION VERSION FOR adex
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('adex', '20260114111014721', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260114111014721', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20251208110333922-v3-0-0', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251208110333922-v3-0-0', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260109031533194', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260109031533194', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20251208110412389-v3-0-0', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251208110412389-v3-0-0', "timestamp" = now();


COMMIT;
