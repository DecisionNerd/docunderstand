# User Guide: Overview

## What docunderstand does

`docunderstand` gives you the tools to work through any VRDU problem — not a single prescribed solution, but a composable set of components covering every stage of document understanding processing.

The library's job is to take a document and produce a standard `ExtractionResult`: a canonical document graph with layout, entities, grounding, and provenance. Downstream systems (pipelines, agents, APIs) consume that result without needing to know which tools processed the document.

---

## The workbench model

Think of `docunderstand` as a workbench with clearly labelled drawers. Each drawer contains interchangeable tools for one stage of the problem. You pick the tools appropriate to your document and assemble them into a pipeline.

```
┌──────────────────────────────────────────────────────────┐
│                     Your VRDU Problem                    │
└────────────────────────────┬─────────────────────────────┘
                             │
              ┌──────────────▼──────────────┐
              │   What kind of document?    │
              │   What quality?             │
              │   What do you need out?     │
              └──────────────┬──────────────┘
                             │
       ┌─────────────────────┼─────────────────────┐
       ▼                     ▼                     ▼
  Born-digital PDF      Scanned document      Camera image
  native extraction     OCR path              heavy preprocessing
  fast, accurate        preprocessing first   + OCR
       │                     │                     │
       └─────────────────────┴─────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ ExtractionResult│  ← always the same shape
                    └─────────────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
       infoextract                  redactor / RAG /
       (business semantics)         agentic workflow
```

---

## Components

### Ingestors

Load a document and record source metadata. Produce `Artifact` objects for each page.

| Component | Use for |
|---|---|
| `PDFIngestor` | All PDF types — detects native vs. scanned automatically |
| `ImageIngestor` | PNG, JPEG, TIFF raster inputs |

### Preprocessors

Transform scans into OCR-ready images. Each step is recorded as a `Transform` with parameters and quality signals — no invisible preprocessing.

| Component | What it does |
|---|---|
| `StandardPreprocessor` | Full chain: border clean → deskew → dewarp → denoise → binarize |
| Individual steps | `Deskewer`, `Denoiser`, `Binarizer` etc. can be composed manually |

### Extractors

Pull text and coordinates from a page.

| Component | Use for |
|---|---|
| `NativeExtractor` | Born-digital PDFs — pixel-accurate, no OCR |
| `OCRExtractor(backend="tesseract")` | Scanned documents, Tesseract backend |
| `OCRExtractor(backend="paddleocr")` | Scanned documents, PaddleOCR backend (better accuracy, multilingual) |

### Layout Analysers

Group tokens into regions and assign structural roles (paragraph, title, page header, table, signature…).

| Component | Use for |
|---|---|
| `HeuristicLayoutAnalyser` | Well-structured documents; fast, no ML dependency |
| `ModelLayoutAnalyser` | Complex or mixed layouts; uses layoutparser or docling |

### Structure Extractors

Pull higher-level structures from the layout.

| Component | Use for |
|---|---|
| `TableExtractor` | Detect and parse tables (line-based or model-based) |
| `KeyValueExtractor` | Form field extraction (schema-driven or proximity-based) |
| `SelectionMarkExtractor` | Checkbox and radio button state detection |

### Grounding

Resolve entity mentions to triple anchors (token IDs + text-stream spans + page polygons).

| Component | Use for |
|---|---|
| `TripleAnchorResolver` | Required for any downstream redaction or pixel-level reference |

---

## Choosing your path

### Born-digital PDF, structured layout

```python
Pipeline([PDFIngestor(), NativeExtractor(), HeuristicLayoutAnalyser(), KeyValueExtractor(schema=...)])
```

No preprocessing, no OCR, fastest path.

### Born-digital PDF, complex layout (tables, mixed columns)

```python
Pipeline([PDFIngestor(), NativeExtractor(), ModelLayoutAnalyser(), TableExtractor(), KeyValueExtractor(schema=...)])
```

### Scanned document, good quality

```python
Pipeline([PDFIngestor(), StandardPreprocessor(), OCRExtractor(backend="tesseract"), HeuristicLayoutAnalyser(), KeyValueExtractor(schema=...)])
```

### Scanned document, poor quality or multilingual

```python
Pipeline([PDFIngestor(), StandardPreprocessor(), OCRExtractor(backend="paddleocr"), ModelLayoutAnalyser(), KeyValueExtractor(schema=...)])
```

### Document requiring redaction

Add `TripleAnchorResolver()` before the final step to ensure every entity has page-polygon anchors. Then pass the `ExtractionResult` to the redactor with the resolved `actions.redactions`.

### End-to-end model (Donut, LayoutLMv3)

For fixed-schema extraction where training data is available and character-level provenance isn't required:

```python
Pipeline([PDFIngestor(), DonutExtractor(model="your-fine-tuned-model")])
```

The output is still an `ExtractionResult`. The model fills `semantics.entities` directly; the `layout` layer is populated with whatever the model emits.

---

## The standard output

Every pipeline produces the same `ExtractionResult` shape:

```python
result.layout.tokens          # Token objects with quads and text-stream spans
result.layout.blocks          # Blocks with structural roles and reading order
result.layout.tables          # Table objects with rows, columns, cells
result.semantics.entities     # Entities with triple anchors and provenance
result.actions.redactions     # Redaction objects with polygon regions
result.artifacts              # Preprocessing lineage
result.telemetry              # Per-page quality signals and timing
```

This is what makes the workbench model practical: downstream code is written once against `ExtractionResult`, and the pipeline that produced it can change without touching the consumer.

---

## Downstream use cases

| Use case | What to consume from ExtractionResult |
|---|---|
| Structured data extraction | `semantics.entities` with normalized values |
| RAG / vector store ingestion | `text_streams` in reading order |
| Agentic tool use | `semantics.entities` + `layout.tables` |
| Document redaction | `actions.redactions` with `page_regions` |
| Human review UI | `layout.tokens` + `semantics.entities` with bounding quads |
| Audit trail | `artifacts`, `transforms`, `telemetry` |
| infoextract handoff | Full `ExtractionResult` — infoextract appends to `semantics` layer |
