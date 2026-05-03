# Requirements

## Purpose

`docunderstand` is a companion library to [infoextract](https://github.com/DecisionNerd/infoextract) for working with visually rich documents — PDFs, scanned forms, invoices, receipts, and any document where spatial layout carries meaning alongside textual content.

The library owns **perception, geometric grounding, reading order, and document-intrinsic structure**. Business semantics, ontology alignment, and entity classification belong to `infoextract`. That boundary is intentional and mirrors how production document platforms are built: Google Document AI emits layout units with text anchors and bounding polygons, then exposes separate entity objects with page anchors; Amazon Textract exposes Block objects with geometry, IDs, and relationships; Microsoft Document Intelligence emits a reading-order content string with bounding regions, then layers structured fields on top.

---

## Functional Requirements

### FR-1: Document Ingestion

- Load documents from local file paths or bytes
- Support PDF (native text and scanned/image-based)
- Support raster images (PNG, JPEG, TIFF)
- Record source MIME type, SHA-256 hash, page count, and ingestion timestamp
- Normalise multi-page documents into per-page representations
- Preserve page dimensions, render DPI, and orientation for coordinate normalisation

### FR-2: Image Preprocessing

- Execute a versioned preprocessing chain before OCR: border clean / crop, deskew, dewarp, denoise, alpha removal, contrast normalisation, binarization
- Record each preprocessing step as an explicit named `Transform` with input artifact IDs, output artifact ID, and parameters (e.g. skew angle, binarization threshold, denoise method)
- Expose quality signals per preprocessing step: blur estimate (Laplacian variance), skew angle, border-darkness ratio, binarization method and threshold
- Minimum render resolution: 300 DPI for OCR paths; 150 DPI for layout-only paths

### FR-3: Text and Layout Extraction

- Extract raw text with **per-token normalised-quad bounding regions** (x0,y0,x1,y1,x2,y2,x3,y3 in page-local \[0,1\] space)
- Expose word, line, block, glyph, and paragraph granularity
- Support native PDF text extraction (no OCR required) and OCR fallback for scanned content
- Auto-select path: native extraction if token density exceeds threshold; OCR otherwise
- Record per-token OCR engine, confidence \[0,1\], raw confidence, raw confidence scale, and text type (printed / handwritten)

### FR-4: Structural Role Labelling

- Label every detected region with a **document-intrinsic structural role**: paragraph, title, section heading, page header, page footer, page number, footnote, figure, table, cell, selection mark, signature
- Record reading order as an ordered graph of `{from, to, relation, confidence}` edges between blocks
- Detect and record printed-vs-handwritten text type per token
- Detect language and script per region where the OCR engine supports it
- Detect reading direction (LTR / RTL / vertical)

These roles are layout- and representation-level facts, not business ontology decisions. They must be owned by `docunderstand`, not by `infoextract`.

### FR-5: Table Detection and Parsing

- Locate table regions within document pages
- Extract table structure: rows, columns, cell contents, spanning cells
- Return tables as structured `Table` / `Cell` objects with per-cell bounding regions and text spans
- Preserve cell merge information (row span, column span)

### FR-6: Selection Mark Detection

- Detect checkboxes, radio buttons, and similar selection marks
- Record state (selected / unselected / unknown) and bounding region

### FR-7: Canonical Document Graph

- Represent the processed document as an **immutable canonical document graph** with stable, unique IDs for: document, artifact, page, block, line, token, glyph, table, cell, entity, relation, action
- Maintain three layers: layout (geometric structure), semantics (entity/relation claims), actions (redactions, annotations)
- Every semantic entity anchor must point to all three: token/glyph IDs, text-stream spans, and page-local polygon regions — the **triple anchor**
- Coordinate space: page-local normalised polygons or quads as canonical; axis-aligned bounding boxes as cached derivatives only

### FR-8: Text Streams

- Assemble a canonical text stream per document in reading order
- Record span unit (grapheme or token) and the full text string
- Every token's `span` must reference `{stream_id, start, end}` into this stream
- The text stream is the stable backbone for text-position selectors; it must survive tokenisation drift across OCR engine versions

### FR-9: Structured Output

- Return an `ExtractionResult` serialisable to JSON and to Pydantic models
- Every extracted field includes: value, confidence \[0,1\], triple anchor (token IDs + text span + page regions), page number, and provenance (extractor ID, model version)
- Preserve `raw_confidence` and `raw_confidence_scale` alongside normalised `confidence`
- Support one-to-many text hypotheses per token where OCR correction or ambiguity is relevant

### FR-10: Redaction Actions

- Represent redaction intent as first-class `Redaction` objects in the actions layer: `{id, entity_id, page_id, regions[], mode, label, confidence, status}`
- `regions[]` is an ordered per-page list of quads/polygons — not a single bounding box — because one entity can span multiple lines, regions, or pages
- Modes: `burn_in` (raster mask), `pdf_redact` (native PDF redaction object + content removal), `metadata_sanitize`
- For born-digital PDFs: apply native PDF redaction objects, remove underlying content, sanitize metadata and attachments; do not treat "draw black rectangles" as complete redaction
- For scanned PDFs: burn masks into the page image layer; sanitize metadata and attachments at the container level
- `status` lifecycle: `proposed` → `approved` → `applied` → `verified`

### FR-11: Preprocessing Artifact Lineage

- Maintain an `artifacts[]` list: source document, rendered page images, preprocessed page images, derived crops
- Maintain a `transforms[]` list: each stage records `{id, stage, input_artifact_ids, output_artifact_ids, params, quality, telemetry}`
- This lineage enables downstream QA, training data generation, and audit

### FR-12: Pipeline Composition

- Allow users to compose extraction steps into a pipeline
- Support custom stages at any point in the pipeline
- Be interoperable with infoextract's semantic extraction primitives

---

## Non-Functional Requirements

### NFR-1: Python Compatibility

- Support Python 3.11, 3.12, 3.13
- Fully type-annotated public API

### NFR-2: Dependencies

- Minimise mandatory dependencies; heavy ML models are optional extras
- Core extraction (native PDF) must work without ML or OCR dependencies
- Optional extras: `[ocr]`, `[layout]`, `[dev]`, `[docs]`

### NFR-3: Performance

- Process a standard single-page document in under 2 seconds on CPU (excluding model load time)
- Process pages individually (streaming); do not hold entire documents in memory

### NFR-4: Correctness

- Bounding region coordinates pixel-accurate for native PDFs
- All coordinates in a consistent documented space; deterministic transform back to native source space preserved
- Unit test coverage ≥ 80%; integration test coverage ≥ 75%

### NFR-5: Extensibility

- Public interfaces use abstract base classes or `Protocol` to allow user-supplied backends
- OCR backend is pluggable (Tesseract, PaddleOCR, cloud APIs)
- Layout backend is pluggable (heuristic, layoutparser, docling)

### NFR-6: Telemetry

- Emit OpenTelemetry-compatible spans per pipeline stage with standardised attributes (see Architecture)
- Quality signals (OCR confidence, skew angle, blur estimate, low-confidence token ratio) emitted as span attributes, not just logs
- Warnings (low-confidence clusters, unresolved regions, sanitize failures) emitted as structured events on the relevant span

### NFR-7: Packaging

- Distributed on PyPI as `docunderstand`

---

## Out of Scope

- Training or fine-tuning ML models
- Cloud storage or remote document fetching (handled by infoextract)
- Full document reconstruction (PDF → Word)
- Handwriting recognition beyond what OCR backends provide
- Business entity classification, ontology alignment, named entity typing (belongs to infoextract)
