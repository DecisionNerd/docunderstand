# Pipeline Architecture

A VRDU pipeline takes a raw document file and produces a structured, grounded, auditable output. This page describes the canonical stages, the design choices at each, and the data contract between them.

---

## Standard Pipeline

```
┌──────────────────────┐
│    Document Input    │  PDF, image (PNG/JPEG/TIFF), bytes
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│     Ingestion        │  Load pages, record source metadata,
│                      │  create source Artifact + page Artifacts
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Image Preprocessing│  border clean → deskew → dewarp →
│   (scans only)       │  denoise → binarize → normalise
│                      │  Each step → named Transform + quality signals
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Text Extraction    │  Native PDF text OR OCR
│   + Coordinates      │  → Tokens with normalised-quad regions
│                      │  + OCR confidence, engine, text type
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Layout Analysis    │  Detect blocks, lines, tables, figures,
│   + Structural Roles │  selection marks, signatures
│                      │  Assign structural role (paragraph, title,
│                      │  page header, footnote, …)
│                      │  Establish reading order graph
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Text Stream        │  Assemble canonical reading-order text
│   Assembly           │  Record {stream_id, start, end} spans
│                      │  per token — stable across engine versions
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Entity / Field     │  Key-value extraction, table parsing,
│   Extraction         │  selection mark state, named entities
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Triple-Anchor      │  Resolve every entity to:
│   Resolution         │  1. token_ids / glyph_ids
│                      │  2. text-stream spans
│                      │  3. page-local polygon regions
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Structured Output  │  ExtractionResult → JSON / Pydantic
│                      │  Includes artifacts[], transforms[],
│                      │  layout{}, semantics{}, actions{},
│                      │  telemetry{}
└──────────────────────┘
```

---

## Stage 1: Ingestion

**Inputs:** file path or bytes  
**Outputs:** `ExtractionResult` with `source`, `artifacts[]`, `pages[]` populated

- Detect format (PDF vs. raster image)
- For PDFs: split into pages, record page dimensions and page count
- For images: normalise colour space (RGB), record dimensions
- Create a `source_document` Artifact with SHA-256 hash
- Create one `rendered_page` Artifact per page (rendered at target DPI)
- Record render parameters as a `Transform`

**Key metadata to record:** MIME type, file hash, page count, render DPI, page dimensions, orientation, source class (scan / photo / born-digital PDF), alpha-channel presence.

---

## Stage 2: Image Preprocessing

**Inputs:** `rendered_page` Artifact  
**Outputs:** `preprocessed_page` Artifact + one `Transform` per operation

This stage only runs for scanned or camera-captured documents. For born-digital PDFs it is a no-op.

**Transform chain:**

| Step | Purpose | Quality signal |
|---|---|---|
| Border clean | Remove dark scan borders that cause false characters | border_dark_ratio |
| Deskew | Correct rotational misalignment | skew_angle_deg |
| Dewarp | Correct page curve from book scanning | dewarp_magnitude |
| Denoise | Remove salt-and-pepper noise | noise_level |
| Alpha removal | Strip alpha channel (breaks Tesseract) | alpha_present |
| Contrast normalise | Improve foreground/background separation | contrast_ratio |
| Binarize | Convert to black-and-white for OCR | method, threshold |

Each step records its parameters and output quality signals on the `Transform` object. This lineage enables downstream QA, debugging, and training data generation.

**Minimum requirements:**
- 300 DPI for OCR paths; 150 DPI for layout-only
- Tesseract requires: ≥300 DPI, no skew, no borders, no alpha channel, binarized input for best results

---

## Stage 3: Text Extraction

**Inputs:** `DocumentPage` (with rendered or preprocessed image)  
**Outputs:** `DocumentPage` populated with `tokens: list[Token]` carrying normalised-quad regions

Two paths:

### Native extraction (born-digital PDFs)

PDFs with embedded text are parsed without OCR. PyMuPDF and pdfplumber extract character or word-level text with exact coordinates. This path is fast, deterministic, and pixel-accurate.

### OCR (scanned / image-only)

OCR returns word bounding boxes, recognised text, and confidence scores. Confidence is normalised to \[0,1\]; raw confidence and scale are preserved.

**Path selection heuristic:**
1. Attempt native extraction — if token density exceeds threshold, use it
2. Fall back to OCR if page appears to be a scan (low token density, image-only PDF stream)

**Per-token records:** text, normalised-quad region, `{stream_id, start, end}` text span, OCR engine, confidence \[0,1\], raw confidence, raw scale, text type (printed / handwritten).

---

## Stage 4: Layout Analysis and Structural Role Labelling

**Inputs:** `DocumentPage` with tokens  
**Outputs:** `DocumentPage` with `blocks: list[Block]`, `lines`, `tables`, `reading_order`

Layout analysis groups tokens into semantic regions and labels each with a **document-intrinsic structural role**.

### Structural roles (owned by docunderstand)

These are layout- and representation-level facts, not business semantics:

`PARAGRAPH` · `TITLE` · `SECTION_HEADING` · `PAGE_HEADER` · `PAGE_FOOTER` · `PAGE_NUMBER` · `FOOTNOTE` · `FIGURE` · `TABLE` · `SELECTION_MARK` · `SIGNATURE`

This matches the role taxonomy emitted by Microsoft Document Intelligence's layout model and the block types exposed by Amazon Textract's layout analysis.

### Reading order

Reading order is an ordered graph of `{from_id, to_id, relation, confidence}` edges between blocks. For simple single-column documents, a top-to-bottom sort by y-coordinate is sufficient. For multi-column, mixed, or complex layouts, a model-based approach (or heuristic column detection) is required.

### Heuristic approach

For well-structured documents, simple rules cover most cases:
- Cluster tokens by y-coordinate proximity into lines
- Cluster lines into blocks using gap thresholds
- Detect column boundaries from x-coordinate distribution
- Assign reading order left-to-right, top-to-bottom within columns

### Model-based approach

For complex layouts, a detection model (DiT, Faster R-CNN on PubLayNet/DocLayNet) identifies region bounding boxes and classifies them by type.

---

## Stage 5: Text Stream Assembly

**Inputs:** blocks and tokens in reading order  
**Outputs:** `TextStream` with full document text; every token's `span` updated with `{stream_id, start, end}`

The canonical text stream is the stable backbone for provenance. It survives tokenisation drift — if OCR engine versions produce different word boundaries, the character-level span in this stream remains valid.

```json
{
  "id": "ts:doc",
  "span_unit": "grapheme",
  "text": "John Smith SSN 123-45-6789 ..."
}
```

Every token carries: `"span": {"stream_id": "ts:doc", "start": 15, "end": 26}`.

---

## Stage 6: Entity and Field Extraction

**Inputs:** `DocumentPage` with tokens, blocks, text stream  
**Outputs:** `semantics.entities[]`, `semantics.relations[]`

### Key-value extraction (forms)

Strategies in order of preference:
1. **Template matching** — use a known form schema to locate fields by structural role and position
2. **Model-based** — LayoutLMv3 or similar classifies each token as key, value, or other, then links pairs
3. **Spatial proximity** — find nearest token to the right of or below each label token

### Table extraction

- **Line detection**: find ruling lines using Hough transform or PDF vector graphics
- **Cell clustering**: group tokens into rows and columns by coordinate alignment
- **Model-based**: table structure recognition model (TATR, TableFormer) for complex/merged cells

### Selection marks

Detect checkbox and radio button state (selected / unselected) by visual appearance within a `SELECTION_MARK` region.

---

## Stage 7: Triple-Anchor Resolution

**Inputs:** `semantics.entities[]` with preliminary token references  
**Outputs:** each entity's `anchors` populated with all three reference types

Resolution precedence:

1. **Token/glyph IDs** — use when available; most precise
2. **Text-stream spans** — fall back when tokenisation shifts between engine versions
3. **Page-local quads** — recover per page; keep disjoint shapes separate unless adjacent in the same line or cell

Only at render time should normalised page-space geometry be converted to pixels or PDF user-space coordinates.

### Why triple anchors matter

A single entity can span multiple lines, regions, or pages. A single bounding box cannot represent this faithfully. Production systems all use array-of-regions: Google Document AI's page anchors are multi-polygon; Azure's bounding regions are arrays; Textract's block relationships are ID graphs. For redaction in particular, `regions[]` is the only safe representation.

---

## Stage 8: Structured Output

**Inputs:** fully populated `ExtractionResult`  
**Outputs:** JSON or Pydantic model

Every extracted field includes:
- `value` — extracted text
- `confidence` — normalised \[0,1\]
- `anchors` — triple anchor (token IDs + text spans + page regions)
- `page` — page number
- `provenance` — extractor ID, model version

`raw_confidence` and `raw_confidence_scale` are preserved per token for auditability.

---

## Design Considerations

### End-to-end models vs. staged pipeline

End-to-end models (Donut, Florence) collapse the pipeline into a single stage: image → structured JSON. They are preferable when:
- The output schema is fixed and known at training time
- Training data is available
- Character-level provenance is not required

They are less suitable when:
- Pixel-accurate redaction is required (grounded token coordinates are essential)
- Human review and audit trails matter
- The document schema is variable or defined at query time
- Multilingual or unsupported-language documents are common

For production redaction and auditability, every model path still needs to emit a grounded contract that ties semantics back to spans, tokens, and page regions.

### Streaming vs. batch

Process pages individually (streaming) for large documents or high-throughput scenarios. `docunderstand` processes page-by-page by default and does not hold entire documents in memory.

### Preprocessing matters

OCR quality is highly sensitive to preprocessing. Tesseract's own guidance shows that skew, borders, noise, alpha channels, and low DPI are the primary causes of degraded accuracy — more so than model choice. Investing in a robust preprocessing chain with explicit lineage tracking pays large dividends in downstream extraction quality.
