- optimization of the processing video 

📥 [2026-01-15T14:45:10.204736] 🚀 processVideoFromUrl called
📥 [2026-01-15T14:45:10.204797]    📹 videoUrl: /uploads/1768468509673_WhatsApp_Video_2026-01-14_at_21.46.35.mp4
📥 [2026-01-15T14:45:10.204804]    💬 userPrompt: Extract nutrition facts, ingredients list, product details, and any health claims from this packed food product video
📥 [2026-01-15T14:45:10.204810]    📝 whatDoesThisVideoContain: Video of a packed food product showing all sides including front label, back label with nutrition facts and ingredients, and any barcodes or certifications
📥 [2026-01-15T14:45:10.204823]    🎯 suggestFramesToExtract: [nutrition_facts, ingredients_list, product_front, product_back, barcode]
📥 [2026-01-15T14:45:10.204829]    📄 extractToText: true
 [2026-01-15T14:45:10.204835] 
🎬 [2026-01-15T14:45:10.204838] ╔══════════════════════════════════════════════════════════════╗
🎬 [2026-01-15T14:45:10.204860] ║           ADEX VIDEO PROCESSING STARTED                      ║
🎬 [2026-01-15T14:45:10.204868] ╚══════════════════════════════════════════════════════════════╝
 [2026-01-15T14:45:10.204872] 
✓ [2026-01-15T14:45:10.204877] ✅ Input validation passed
⚙️ [2026-01-15T14:45:10.204886] 📋 Processing Configuration:
⚙️ [2026-01-15T14:45:10.204890]    🆔 Processing ID: 1768468510204_hevb7ugzwy
⚙️ [2026-01-15T14:45:10.204894]    📹 Video URL: /uploads/1768468509673_WhatsApp_Video_2026-01-14_at_21.46.35.mp4
⚙️ [2026-01-15T14:45:10.204899]    💬 User Prompt: Extract nutrition facts, ingredients list, product...
⚙️ [2026-01-15T14:45:10.204903]    📄 Extract to Text: true
⚙️ [2026-01-15T14:45:10.204906]    🔢 Concurrency: 8 frames
 [2026-01-15T14:45:10.205019] 
📝 [2026-01-15T14:45:10.205049] ┌─────────────────────────────────────────────────────────────┐
📝 [2026-01-15T14:45:10.205056] │  STEP 1: Creating AdexModel Database Entry                  │
📝 [2026-01-15T14:45:10.205061] └─────────────────────────────────────────────────────────────┘
🗄️ [2026-01-15T14:45:10.205068] 💾 Inserting AdexModel into database...
✓ [2026-01-15T14:45:10.210800] ✅ AdexModel created successfully!
✓ [2026-01-15T14:45:10.210826]    🆔 AdexModel ID: 8
✓ [2026-01-15T14:45:10.210831]    ⏱️  Time: 5ms
 [2026-01-15T14:45:10.210835] 
🔐 [2026-01-15T14:45:10.210837] ┌─────────────────────────────────────────────────────────────┐
🔐 [2026-01-15T14:45:10.210843] │  STEP 2: Fetching Vertex AI Access Token                    │
🔐 [2026-01-15T14:45:10.210847] └─────────────────────────────────────────────────────────────┘
🔐 [2026-01-15T14:45:10.210853] 🔑 Authenticating with Google Cloud...
🔐 [2026-01-15T14:45:10.210857] 🔐 _getAccessToken: Fetching token...
🔐 [2026-01-15T14:45:10.210866]    📧 Service account: vetex-ai-user-serverpod@weedit-india.iam.gserviceaccount.com
🔐 [2026-01-15T14:45:10.210924]    🌐 Token URI: https://oauth2.googleapis.com/token
🔐 [2026-01-15T14:45:10.211472]    🔄 Requesting token from Google...
✓ [2026-01-15T14:45:10.736128]    ✅ Token obtained: ya29.c.c0AZ1aNiWsSDR...
✓ [2026-01-15T14:45:10.736168] ✅ Access token obtained!
✓ [2026-01-15T14:45:10.736174]    🔑 Token: ya29.c.c0AZ1aNiWsSDR...
✓ [2026-01-15T14:45:10.736182]    ⏱️  Time: 525ms
 [2026-01-15T14:45:10.736186] 
🎞️ [2026-01-15T14:45:10.736189] ┌─────────────────────────────────────────────────────────────┐
🎞️ [2026-01-15T14:45:10.736194] │  STEP 3: Extracting Frames & Generating Embeddings          │
🎞️ [2026-01-15T14:45:10.736198] └─────────────────────────────────────────────────────────────┘
📂 [2026-01-15T14:45:10.736214] 📁 Creating temporary directory...
📂 [2026-01-15T14:45:10.736500]    📂 Temp dir: /var/folders/n4/zkrh5x055cld57d543_tq_cw0000gn/T/adex_processing_L76Zlo
🎬 [2026-01-15T14:45:10.736540] 🎞️  _extractFramesAndGenerateEmbeddings: Starting...
🎬 [2026-01-15T14:45:10.736761]    📁 Frames directory: /var/folders/n4/zkrh5x055cld57d543_tq_cw0000gn/T/adex_processing_L76Zlo/frames
🎬 [2026-01-15T14:45:10.736778]    📹 Video path: uploads/1768468509673_WhatsApp_Video_2026-01-14_at_21.46.35.mp4
🎬 [2026-01-15T14:45:10.736839]    ✅ Video file found locally
🎬 [2026-01-15T14:45:10.736851]    ⏱️  Getting video duration with ffprobe...
🎬 [2026-01-15T14:45:10.885402]    📊 Video duration: 18.26 seconds
🎬 [2026-01-15T14:45:10.885497]    🎞️  Extracting frames at 2 FPS with FFmpeg...
🎬 [2026-01-15T14:45:11.629144]    ✅ Extracted 37 frames in 743ms
🧠 [2026-01-15T14:45:11.629227]    🧠 Generating embeddings for 37 frames...
🧠 [2026-01-15T14:45:11.629233]    ⚡ Concurrency: 8 parallel requests
🧠 [2026-01-15T14:45:11.629247]    📦 Batch 1: frames 1-8
🧠 [2026-01-15T14:45:15.196019]    ✅ Batch 1 complete (8/37 total)
🧠 [2026-01-15T14:45:15.196253]    📦 Batch 2: frames 9-16
🧠 [2026-01-15T14:45:18.674125]    ✅ Batch 2 complete (16/37 total)
🧠 [2026-01-15T14:45:18.674233]    📦 Batch 3: frames 17-24
🧠 [2026-01-15T14:45:22.032324]    ✅ Batch 3 complete (24/37 total)
🧠 [2026-01-15T14:45:22.032441]    📦 Batch 4: frames 25-32
🧠 [2026-01-15T14:45:25.471823]    ✅ Batch 4 complete (32/37 total)
🧠 [2026-01-15T14:45:25.471927]    📦 Batch 5: frames 33-37
🧠 [2026-01-15T14:45:28.823007]    ✅ Batch 5 complete (37/37 total)
🧠 [2026-01-15T14:45:28.823227]    ✅ All embeddings generated in 17s
🗄️ [2026-01-15T14:45:28.823245]    💾 Inserting 37 frames to database...
🗄️ [2026-01-15T14:45:28.896896]    ✅ Database insert complete in 73ms
✓ [2026-01-15T14:45:28.896947] ✅ Frame extraction & embedding complete!
✓ [2026-01-15T14:45:28.896957]    🎞️  Total frames: 37
✓ [2026-01-15T14:45:28.896964]    ⏱️  Duration: 18.2621s
✓ [2026-01-15T14:45:28.896970]    ⏱️  Processing time: 18s
 [2026-01-15T14:45:28.896973] 
🤖 [2026-01-15T14:45:28.896976] ┌─────────────────────────────────────────────────────────────┐
🤖 [2026-01-15T14:45:28.896981] │  STEP 4: RAG - Generating Frame Types with Gemini           │
🤖 [2026-01-15T14:45:28.896987] └─────────────────────────────────────────────────────────────┘
🤖 [2026-01-15T14:45:28.896993] 🧠 Calling Gemini to analyze frame requirements...
🤖 [2026-01-15T14:45:28.896998] 🤖 _generateFrameTypes: Calling Gemini API...
🤖 [2026-01-15T14:45:28.897013]    🌐 Sending request to Gemini...
🤖 [2026-01-15T14:45:33.320857]    ✅ Gemini response received
🤖 [2026-01-15T14:45:33.321053]    ✅ Valid JSON response received
✓ [2026-01-15T14:45:33.321064] ✅ Frame types generated!
✓ [2026-01-15T14:45:33.321069]    📋 Frame Types JSON:
 [2026-01-15T14:45:33.321178]       {
 [2026-01-15T14:45:33.321184]          "nutrition_facts": {
 [2026-01-15T14:45:33.321187]             "description": "Close-up shot of the nutrition facts label on the product packaging. The label should clearly display serving size, calories, total fat, saturated fat, trans fat, cholesterol, sodium, total carbohydrate, dietary fiber, total sugars, added sugars, protein, vitamin D, calcium, iron, and potassium. Ensure all values and units are legible.",
 [2026-01-15T14:45:33.321190]             "extractFrameCount": 3
 [2026-01-15T14:45:33.321193]          },
 [2026-01-15T14:45:33.321197]          "ingredients_list": {
 [2026-01-15T14:45:33.321200]             "description": "Clear image of the ingredients list on the product packaging. The list should display all ingredients in descending order by weight. Capture any allergen warnings or disclaimers present near the ingredients list. Ensure all text is readable.",
 [2026-01-15T14:45:33.321204]             "extractFrameCount": 3
 [2026-01-15T14:45:33.321207]          },
 [2026-01-15T14:45:33.321209]          "product_front": {
 [2026-01-15T14:45:33.321212]             "description": "Front-facing view of the product packaging. The image should clearly show the product name, brand name, and any prominent marketing claims or imagery. Ensure the entire front label is visible and in focus.",
 [2026-01-15T14:45:33.321215]             "extractFrameCount": 1
 [2026-01-15T14:45:33.321217]          },
 [2026-01-15T14:45:33.321220]          "product_back": {
 [2026-01-15T14:45:33.321223]             "description": "Full view of the back of the product packaging. This should include the nutrition facts label, ingredients list, manufacturer information, and any other relevant information printed on the back. Ensure the entire back label is visible and in focus.",
 [2026-01-15T14:45:33.321232]             "extractFrameCount": 1
 [2026-01-15T14:45:33.321234]          },
 [2026-01-15T14:45:33.321237]          "barcode": {
 [2026-01-15T14:45:33.321239]             "description": "Close-up shot of the product's barcode (UPC or EAN). The barcode should be in focus and easily scannable. Capture any surrounding text or numbers associated with the barcode.",
 [2026-01-15T14:45:33.321242]             "extractFrameCount": 2
 [2026-01-15T14:45:33.321244]          },
 [2026-01-15T14:45:33.321247]          "health_claims": {
 [2026-01-15T14:45:33.321249]             "description": "Frames capturing any health claims made on the product packaging, such as 'low fat,' 'high fiber,' 'gluten-free,' or any other statements related to health benefits. Ensure the claim and its context on the packaging are visible.",
 [2026-01-15T14:45:33.321256]             "extractFrameCount": 2
 [2026-01-15T14:45:33.321260]          }
 [2026-01-15T14:45:33.321263]       }
🗄️ [2026-01-15T14:45:33.321266] 💾 Updating AdexModel with frame types...
✓ [2026-01-15T14:45:33.329155] ✅ AdexModel updated!
 [2026-01-15T14:45:33.329188] 
🔍 [2026-01-15T14:45:33.329192] ┌─────────────────────────────────────────────────────────────┐
🔍 [2026-01-15T14:45:33.329198] │  STEP 5: RAG - Extracting Matching Frames                   │
🔍 [2026-01-15T14:45:33.329203] └─────────────────────────────────────────────────────────────┘
🔍 [2026-01-15T14:45:33.329207] 🔍 Searching for matching frames using embeddings...
🔍 [2026-01-15T14:45:33.329212] 🔍 _extractFramesUsingRag: Starting RAG extraction...
🔍 [2026-01-15T14:45:33.329283]    📋 Frame types to extract: [nutrition_facts, ingredients_list, product_front, product_back, barcode, health_claims]
🔍 [2026-01-15T14:45:33.329813]    📁 Created output dir: uploads/extracted_frames/8
 [2026-01-15T14:45:33.329943] 
🔍 [2026-01-15T14:45:33.329960]    🏷️  [1/6] Processing: nutrition_facts
🔍 [2026-01-15T14:45:33.329966]       📝 Description: Close-up shot of the nutrition facts label on the product pa...
🔍 [2026-01-15T14:45:33.329972]       🔢 Frames to extract: 3
🔍 [2026-01-15T14:45:33.329975]       🧠 Generating embedding for description...
🧠 [2026-01-15T14:45:33.329981]    📝 Generating text embedding for: "Close-up shot of the nutrition facts label on the ..."
🧠 [2026-01-15T14:45:35.268551]    ✅ Text embedding generated (1408 dimensions)
🔍 [2026-01-15T14:45:35.268597]       🔎 Querying database for similar frames...
🔍 [2026-01-15T14:45:35.276536]       ✅ Found 3 matching frames
💾 [2026-01-15T14:45:35.278626]       📸 Saved: nutrition_facts_1_1768468535276.png (frame #27, 13.5s)
💾 [2026-01-15T14:45:35.279739]       📸 Saved: nutrition_facts_2_1768468535278.png (frame #28, 14.0s)
💾 [2026-01-15T14:45:35.280824]       📸 Saved: nutrition_facts_3_1768468535279.png (frame #30, 15.0s)
✓ [2026-01-15T14:45:35.280854]       ✅ Extracted 3 frames for nutrition_facts
 [2026-01-15T14:45:35.280862] 
🔍 [2026-01-15T14:45:35.280867]    🏷️  [2/6] Processing: ingredients_list
🔍 [2026-01-15T14:45:35.280873]       📝 Description: Clear image of the ingredients list on the product packaging...
🔍 [2026-01-15T14:45:35.280879]       🔢 Frames to extract: 3
🔍 [2026-01-15T14:45:35.280882]       🧠 Generating embedding for description...
🧠 [2026-01-15T14:45:35.280891]    📝 Generating text embedding for: "Clear image of the ingredients list on the product..."
🧠 [2026-01-15T14:45:37.154776]    ✅ Text embedding generated (1408 dimensions)
🔍 [2026-01-15T14:45:37.154820]       🔎 Querying database for similar frames...
🔍 [2026-01-15T14:45:37.162584]       ✅ Found 3 matching frames
💾 [2026-01-15T14:45:37.164032]       📸 Saved: ingredients_list_1_1768468537162.png (frame #10, 5.0s)
💾 [2026-01-15T14:45:37.165209]       📸 Saved: ingredients_list_2_1768468537164.png (frame #3, 1.5s)
💾 [2026-01-15T14:45:37.166501]       📸 Saved: ingredients_list_3_1768468537165.png (frame #11, 5.5s)
✓ [2026-01-15T14:45:37.166519]       ✅ Extracted 3 frames for ingredients_list
 [2026-01-15T14:45:37.166527] 
🔍 [2026-01-15T14:45:37.166531]    🏷️  [3/6] Processing: product_front
🔍 [2026-01-15T14:45:37.166538]       📝 Description: Front-facing view of the product packaging. The image should...
🔍 [2026-01-15T14:45:37.166545]       🔢 Frames to extract: 1
🔍 [2026-01-15T14:45:37.166549]       🧠 Generating embedding for description...
🧠 [2026-01-15T14:45:37.166556]    📝 Generating text embedding for: "Front-facing view of the product packaging. The im..."
🧠 [2026-01-15T14:45:39.056081]    ✅ Text embedding generated (1408 dimensions)
🔍 [2026-01-15T14:45:39.056128]       🔎 Querying database for similar frames...
🔍 [2026-01-15T14:45:39.062470]       ✅ Found 1 matching frames
💾 [2026-01-15T14:45:39.065143]       📸 Saved: product_front_1_1768468539062.png (frame #27, 13.5s)
✓ [2026-01-15T14:45:39.065266]       ✅ Extracted 1 frames for product_front
 [2026-01-15T14:45:39.065314] 
🔍 [2026-01-15T14:45:39.065323]    🏷️  [4/6] Processing: product_back
🔍 [2026-01-15T14:45:39.065330]       📝 Description: Full view of the back of the product packaging. This should ...
🔍 [2026-01-15T14:45:39.065336]       🔢 Frames to extract: 1
🔍 [2026-01-15T14:45:39.065340]       🧠 Generating embedding for description...
🧠 [2026-01-15T14:45:39.065346]    📝 Generating text embedding for: "Full view of the back of the product packaging. Th..."
🧠 [2026-01-15T14:45:41.003330]    ✅ Text embedding generated (1408 dimensions)
🔍 [2026-01-15T14:45:41.003372]       🔎 Querying database for similar frames...
🔍 [2026-01-15T14:45:41.009511]       ✅ Found 1 matching frames
💾 [2026-01-15T14:45:41.012810]       📸 Saved: product_back_1_1768468541009.png (frame #3, 1.5s)
✓ [2026-01-15T14:45:41.012836]       ✅ Extracted 1 frames for product_back
 [2026-01-15T14:45:41.012844] 
🔍 [2026-01-15T14:45:41.012848]    🏷️  [5/6] Processing: barcode
🔍 [2026-01-15T14:45:41.012860]       📝 Description: Close-up shot of the product's barcode (UPC or EAN). The bar...
🔍 [2026-01-15T14:45:41.012866]       🔢 Frames to extract: 2
🔍 [2026-01-15T14:45:41.012869]       🧠 Generating embedding for description...
🧠 [2026-01-15T14:45:41.012876]    📝 Generating text embedding for: "Close-up shot of the product's barcode (UPC or EAN..."
🧠 [2026-01-15T14:45:42.844998]    ✅ Text embedding generated (1408 dimensions)
🔍 [2026-01-15T14:45:42.845045]       🔎 Querying database for similar frames...
🔍 [2026-01-15T14:45:42.851240]       ✅ Found 2 matching frames
💾 [2026-01-15T14:45:42.853361]       📸 Saved: barcode_1_1768468542851.png (frame #29, 14.5s)
💾 [2026-01-15T14:45:42.854333]       📸 Saved: barcode_2_1768468542853.png (frame #27, 13.5s)
✓ [2026-01-15T14:45:42.854347]       ✅ Extracted 2 frames for barcode
 [2026-01-15T14:45:42.854353] 
🔍 [2026-01-15T14:45:42.854358]    🏷️  [6/6] Processing: health_claims
🔍 [2026-01-15T14:45:42.854364]       📝 Description: Frames capturing any health claims made on the product packa...
🔍 [2026-01-15T14:45:42.854370]       🔢 Frames to extract: 2
🔍 [2026-01-15T14:45:42.854374]       🧠 Generating embedding for description...
🧠 [2026-01-15T14:45:42.854380]    📝 Generating text embedding for: "Frames capturing any health claims made on the pro..."
🧠 [2026-01-15T14:45:44.705139]    ✅ Text embedding generated (1408 dimensions)
🔍 [2026-01-15T14:45:44.705184]       🔎 Querying database for similar frames...
🔍 [2026-01-15T14:45:44.726993]       ✅ Found 2 matching frames
💾 [2026-01-15T14:45:44.729097]       📸 Saved: health_claims_1_1768468544727.png (frame #14, 7.0s)
💾 [2026-01-15T14:45:44.730278]       📸 Saved: health_claims_2_1768468544729.png (frame #33, 16.5s)
✓ [2026-01-15T14:45:44.730302]       ✅ Extracted 2 frames for health_claims
 [2026-01-15T14:45:44.730309] 
🔍 [2026-01-15T14:45:44.730313]    🏁 RAG extraction complete: 6 frame types processed
✓ [2026-01-15T14:45:44.730320] ✅ RAG frame extraction complete!
✓ [2026-01-15T14:45:44.730357]    📊 Extracted 6 frame types
✓ [2026-01-15T14:45:44.730386]    ⏱️  Time: 15s
 [2026-01-15T14:45:44.730402]    🖼️  nutrition_facts: 3 frames
 [2026-01-15T14:45:44.730407]    🖼️  ingredients_list: 3 frames
 [2026-01-15T14:45:44.730412]    🖼️  product_front: 1 frames
 [2026-01-15T14:45:44.730417]    🖼️  product_back: 1 frames
 [2026-01-15T14:45:44.730421]    🖼️  barcode: 2 frames
 [2026-01-15T14:45:44.730425]    🖼️  health_claims: 2 frames
🗄️ [2026-01-15T14:45:44.730429] 💾 Updating AdexModel with extracted frames...
✓ [2026-01-15T14:45:44.738516] ✅ AdexModel updated!
 [2026-01-15T14:45:44.738547] 
📝 [2026-01-15T14:45:44.738551] ┌─────────────────────────────────────────────────────────────┐
📝 [2026-01-15T14:45:44.738557] │  STEP 6: Extracting Text from Frames with Gemini            │
📝 [2026-01-15T14:45:44.738561] └─────────────────────────────────────────────────────────────┘
📝 [2026-01-15T14:45:44.738568] 📖 Extracting text from 6 frame types...
📝 [2026-01-15T14:45:44.738593] 📝 _extractTextFromFrames: Starting text extraction...
📝 [2026-01-15T14:45:44.738600]    📋 Processing 6 frame types
 [2026-01-15T14:45:44.738613] 
📝 [2026-01-15T14:45:44.738617]    📖 [1/6] Extracting text from: nutrition_facts
📝 [2026-01-15T14:45:44.738622]       🖼️  Images: 3
📝 [2026-01-15T14:45:44.740824]       📎 Added image: nutrition_facts_1_1768468535276.png
📝 [2026-01-15T14:45:44.743029]       📎 Added image: nutrition_facts_2_1768468535278.png
📝 [2026-01-15T14:45:44.744908]       📎 Added image: nutrition_facts_3_1768468535279.png
📝 [2026-01-15T14:45:44.744924]       🤖 Calling Gemini for text extraction...
✓ [2026-01-15T14:45:49.909966]       ✅ Parsed as JSON successfully
✓ [2026-01-15T14:45:49.910031]       ✅ Text extracted for nutrition_facts
 [2026-01-15T14:45:49.910040] 
📝 [2026-01-15T14:45:49.910045]    📖 [2/6] Extracting text from: ingredients_list
📝 [2026-01-15T14:45:49.910052]       🖼️  Images: 3
📝 [2026-01-15T14:45:49.912793]       📎 Added image: ingredients_list_1_1768468537162.png
📝 [2026-01-15T14:45:49.915362]       📎 Added image: ingredients_list_2_1768468537164.png
📝 [2026-01-15T14:45:49.918227]       📎 Added image: ingredients_list_3_1768468537165.png
📝 [2026-01-15T14:45:49.918258]       🤖 Calling Gemini for text extraction...
✓ [2026-01-15T14:45:55.032264]       ✅ Parsed as JSON successfully
✓ [2026-01-15T14:45:55.032388]       ✅ Text extracted for ingredients_list
 [2026-01-15T14:45:55.032396] 
📝 [2026-01-15T14:45:55.032401]    📖 [3/6] Extracting text from: product_front
📝 [2026-01-15T14:45:55.032406]       🖼️  Images: 1
📝 [2026-01-15T14:45:55.035581]       📎 Added image: product_front_1_1768468539062.png
📝 [2026-01-15T14:45:55.035619]       🤖 Calling Gemini for text extraction...
✓ [2026-01-15T14:46:00.662920]       ✅ Parsed as JSON successfully
✓ [2026-01-15T14:46:00.662959]       ✅ Text extracted for product_front
 [2026-01-15T14:46:00.662965] 
📝 [2026-01-15T14:46:00.662970]    📖 [4/6] Extracting text from: product_back
📝 [2026-01-15T14:46:00.662975]       🖼️  Images: 1
📝 [2026-01-15T14:46:00.665826]       📎 Added image: product_back_1_1768468541009.png
📝 [2026-01-15T14:46:00.665865]       🤖 Calling Gemini for text extraction...
✓ [2026-01-15T14:46:03.937990]       ✅ Parsed as JSON successfully
✓ [2026-01-15T14:46:03.938033]       ✅ Text extracted for product_back
 [2026-01-15T14:46:03.938039] 
📝 [2026-01-15T14:46:03.938044]    📖 [5/6] Extracting text from: barcode
📝 [2026-01-15T14:46:03.938049]       🖼️  Images: 2
📝 [2026-01-15T14:46:03.940909]       📎 Added image: barcode_1_1768468542851.png
📝 [2026-01-15T14:46:03.943123]       📎 Added image: barcode_2_1768468542853.png
📝 [2026-01-15T14:46:03.943141]       🤖 Calling Gemini for text extraction...
❌ [2026-01-15T14:46:07.521580]       ❌ Gemini API error: 429
 [2026-01-15T14:46:07.521683] 
📝 [2026-01-15T14:46:07.521690]    📖 [6/6] Extracting text from: health_claims
📝 [2026-01-15T14:46:07.521695]       🖼️  Images: 2
📝 [2026-01-15T14:46:07.524372]       📎 Added image: health_claims_1_1768468544727.png
📝 [2026-01-15T14:46:07.526713]       📎 Added image: health_claims_2_1768468544729.png
📝 [2026-01-15T14:46:07.526740]       🤖 Calling Gemini for text extraction...
❌ [2026-01-15T14:46:10.286326]       ❌ Gemini API error: 429
 [2026-01-15T14:46:10.286405] 
📝 [2026-01-15T14:46:10.286415]    🏁 Text extraction complete: 4 types extracted
✓ [2026-01-15T14:46:10.286499] ✅ Text extraction complete!
✓ [2026-01-15T14:46:10.286516]    ⏱️  Time: 25s
✓ [2026-01-15T14:46:10.286621]    📋 Extracted data keys: [nutrition_facts, ingredients_list, product_front, product_back]
🗄️ [2026-01-15T14:46:10.286631] 💾 Updating AdexModel with extracted text...
✓ [2026-01-15T14:46:10.293780] ✅ AdexModel updated!
 [2026-01-15T14:46:10.293813] 
🧹 [2026-01-15T14:46:10.293817] ┌─────────────────────────────────────────────────────────────┐
🧹 [2026-01-15T14:46:10.293823] │  STEP 7: Cleaning Up Temporary Data                         │
🧹 [2026-01-15T14:46:10.293828] └─────────────────────────────────────────────────────────────┘
🧹 [2026-01-15T14:46:10.293833] 🗑️  Deleting temporary embeddings from database...
🧹 [2026-01-15T14:46:10.293838] 🧹 _cleanupTemporaryData: Starting cleanup...
🧹 [2026-01-15T14:46:10.293843]    🔍 Finding frames to delete...
🧹 [2026-01-15T14:46:10.301130]    📊 Found 37 frames to clean up
🧹 [2026-01-15T14:46:10.302184]    🗑️  Deleted 0 temp files from disk
🧹 [2026-01-15T14:46:10.302212]    💾 Deleting 37 database entries...
✓ [2026-01-15T14:46:10.307606]    ✅ Cleanup complete: 37 embeddings removed
✓ [2026-01-15T14:46:10.307682] ✅ Cleanup complete!
🗄️ [2026-01-15T14:46:10.307688] 💾 Marking job as completed...
 [2026-01-15T14:46:10.311121] 
🎉 [2026-01-15T14:46:10.311143] ╔══════════════════════════════════════════════════════════════╗
🎉 [2026-01-15T14:46:10.311150] ║           🎉 VIDEO PROCESSING COMPLETE! 🎉                   ║
🎉 [2026-01-15T14:46:10.311155] ╠══════════════════════════════════════════════════════════════╣
🎉 [2026-01-15T14:46:10.311160] ║  📊 Summary:                                                 ║
🎉 [2026-01-15T14:46:10.311168] ║     🆔 AdexModel ID: 8                                   ║
🎉 [2026-01-15T14:46:10.311184] ║     ⏱️  Total Time: 1m 0s                                    ║
🎉 [2026-01-15T14:46:10.311194] ║     📹 Status: completed                                 ║
🎉 [2026-01-15T14:46:10.311198] ╚══════════════════════════════════════════════════════════════╝
 [2026-01-15T14:46:10.311203] 
🧹 [2026-01-15T14:46:10.311321] 🗑️  Deleting temp directory: /var/folders/n4/zkrh5x055cld57d543_tq_cw0000gn/T/adex_processing_L76Zlo
✓ [2026-01-15T14:46:10.314422] ✅ Temp directory deleted


suggestions :
you do few thing parallelly 
you can upload extracted frames in the background .
find more may to optmize this
