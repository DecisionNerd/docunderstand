# Requirements

## Purpose

`docunderstand` is a companion library to [infoextract](https://github.com/DecisionNerd/infoextract) for working with visually rich documents — PDFs, scanned forms, invoices, receipts, and any document where spatial layout carries meaning alongside textual content.

The library provides building blocks for VRDU pipelines: document ingestion, layout-aware text extraction, spatial relationship modelling, entity extraction, and structured output.

---

## Functional Requirements

### FR-1: Document Ingestion

- Load documents from local file paths
- Support PDF (native text and scanned/image-based)
- Support raster images (PNG, JPEG, TIFF)
- Normalise multi-page documents into per-page representations
- Preserve page dimensions for coordinate normalisation

### FR-2: Text and Layout Extraction

- Extract raw text with bounding box coordinates (x_min, y_min, x_max, y_max)
- Preserve word-level, line-level, and block-level granularity
- Support both native PDF text (no OCR required) and OCR fallback for scanned content
- Return coordinates normalised to \[0, 1\] relative to page dimensions

### FR-3: Layout Analysis

- Detect document regions: text blocks, tables, figures, headers, footers
- Establish reading order across multi-column and complex layouts
- Identify document hierarchy (title, section heading, body, caption)

### FR-4: Table Detection and Parsing

- Locate tables within document pages
- Extract table structure: rows, columns, and cell contents
- Handle merged cells and spanning headers
- Return tables as structured objects (list of lists or dataframe-compatible)

### FR-5: Key-Value Extraction

- Identify field labels and their associated values in forms
- Handle spatial proximity-based pairing (label left of value, label above value)
- Support both typed (checkboxes, dates, amounts) and free-text values

### FR-6: Entity and Field Extraction

- Extract named entities relevant to document type (amounts, dates, names, addresses, identifiers)
- Support document-type-aware extraction schemas
- Accept user-defined extraction schemas for ad-hoc field extraction

### FR-7: Structured Output

- Return results as typed Python dataclasses or Pydantic models
- Support serialisation to JSON and dict
- Preserve provenance: which page, bounding box, and confidence score for each extracted value

### FR-8: Pipeline Composition

- Allow users to compose extraction steps into a pipeline
- Support custom stages at any point in the pipeline
- Be interoperable with infoextract's extraction primitives

---

## Non-Functional Requirements

### NFR-1: Python Compatibility

- Support Python 3.11, 3.12, 3.13
- Type-annotated public API throughout

### NFR-2: Dependencies

- Minimise mandatory dependencies; keep heavy ML models optional
- Core extraction (native PDF) must work without ML dependencies
- OCR and layout model capabilities are optional extras

### NFR-3: Performance

- Process a standard single-page document in under 2 seconds on CPU (excluding model loading)
- Avoid holding entire documents in memory; support page-by-page streaming

### NFR-4: Correctness

- Coordinate extraction must be pixel-accurate for native PDFs
- Bounding boxes must be returned in a consistent, documented coordinate space
- Unit test coverage ≥ 80%; integration test coverage ≥ 75%

### NFR-5: Extensibility

- Public interfaces use abstract base classes or protocols to allow user-supplied backends
- OCR backend is pluggable (Tesseract, PaddleOCR, cloud APIs)

### NFR-6: Packaging

- Distributed on PyPI as `docunderstand`
- Optional extras: `[ocr]`, `[layout]`, `[docs]`, `[dev]`

---

## Out of Scope

- Training or fine-tuning of ML models
- Cloud storage or remote document fetching (handled by infoextract)
- Full document reconstruction (e.g. PDF→Word)
- Handwriting recognition beyond what OCR backends provide
