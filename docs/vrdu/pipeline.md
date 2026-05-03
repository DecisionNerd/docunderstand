# Pipeline Architecture

A standard VRDU pipeline takes a raw document file and produces structured, machine-readable output. This page describes the canonical stages and the design choices at each.

---

## Standard Pipeline

```
┌─────────────────┐
│  Document Input │  PDF, image (PNG/JPEG/TIFF)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Ingestion     │  Load pages, normalise to images + dimensions
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Text Extraction │  Native PDF text OR OCR (scanned)
│  + Coordinates  │  → list of Token(text, bbox, confidence)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Layout Analysis │  Detect regions, tables, headers, reading order
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Entity/Field   │  Key-value extraction, table parsing,
│   Extraction    │  named entity recognition
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Structured Output│  ExtractionResult → JSON / Pydantic model
└─────────────────┘
```

---

## Stage 1: Ingestion

**Inputs:** file path or bytes  
**Outputs:** list of `DocumentPage` (dimensions, raw image bytes)

Responsibilities:
- Detect document format (PDF vs. image)
- For PDFs: split into pages, record page dimensions
- For images: normalise colour space (RGB), record dimensions
- Render PDF pages to raster images when downstream stages need pixel data

Key decision: **render resolution**. 150 DPI is sufficient for layout analysis; 300 DPI is recommended for OCR accuracy on small text.

---

## Stage 2: Text Extraction

**Inputs:** `DocumentPage`  
**Outputs:** `DocumentPage` populated with `tokens: list[Token]`

Two paths:

### Native extraction (structured PDFs)

PDFs with embedded text (the majority of digitally-created PDFs) can be parsed without OCR. Libraries like pdfplumber or PyMuPDF extract character or word-level text with exact coordinates. This path is fast, deterministic, and pixel-accurate.

### OCR (scanned / image-only PDFs)

Scanned documents require OCR to recover text. The OCR engine returns word bounding boxes alongside recognised text and a confidence score. Accuracy depends on scan quality, resolution, and font type.

**Backend selection heuristic:**
1. Attempt native extraction — if sufficient text is found (token density above threshold), use it
2. Fall back to OCR if page appears to be a scan (low text density, image-only PDF)

---

## Stage 3: Layout Analysis

**Inputs:** `DocumentPage` with tokens  
**Outputs:** `DocumentPage` with `regions: list[Region]`

Layout analysis groups tokens into semantic regions and establishes reading order.

### Heuristic approach

For well-structured documents, simple rules are often sufficient:
- Cluster tokens by y-coordinate proximity into lines
- Cluster lines into blocks using gap thresholds
- Detect likely column boundaries from x-coordinate distribution
- Assign reading order left-to-right, top-to-bottom within columns

### Model-based approach

For complex layouts (mixed columns, sidebars, tables interspersed with text), a detection model (DiT, Faster R-CNN on PubLayNet) identifies region bounding boxes and classifies them by type.

---

## Stage 4: Entity and Field Extraction

**Inputs:** `DocumentPage` with tokens and regions  
**Outputs:** `ExtractionResult` fields

### Key-value extraction (forms)

Forms contain label-value pairs. Pairing strategies:

- **Spatial proximity**: find the nearest token to the right of or below a label token
- **Template matching**: use a known form schema to locate fields by position
- **Model-based**: use LayoutLMv3 or similar to classify each token as key, value, or other, then link pairs

### Table extraction

Table cells are identified by row/column grid structure. Strategies:
- **Line detection**: find ruling lines using Hough transform or PDF vector graphics
- **Cell clustering**: group tokens into rows and columns by coordinate alignment
- **Model-based**: use a table structure recognition model (TATR, TableFormer)

### Named entity extraction

Standard NER models (spaCy, Hugging Face NER) can be applied to the extracted token sequence. Layout-aware models (LayoutLMv3 fine-tuned for NER) outperform text-only NER by leveraging spatial context.

---

## Stage 5: Structured Output

**Inputs:** extracted fields and tables  
**Outputs:** `ExtractionResult` (serialisable to JSON / dict)

Every extracted field includes:
- `value` — the extracted text
- `confidence` — model or OCR confidence
- `bbox` — source location on the page
- `page` — page number

This provenance information enables downstream systems to highlight source regions, audit extractions, and handle low-confidence cases with human review.

---

## Design Considerations

### When to use end-to-end models

End-to-end models like Donut collapse the pipeline into a single stage: image → structured JSON. They are preferable when:
- The output schema is fixed and known at training time
- You have representative training data for fine-tuning
- You want to avoid maintaining an explicit OCR pipeline

They are less preferable when:
- The document schema is variable or defined at query time
- You need character-level provenance (bounding boxes per extracted field)
- You need to process documents in unsupported languages

### Streaming vs. batch

For large documents or high-throughput scenarios, process pages individually (streaming) rather than loading entire documents into memory. `docunderstand` processes page-by-page by default.
