# Architecture

## Overview

`docunderstand` is the go-to Python workbench for VRDU processing. It is not a single prescribed pipeline — it is a composable set of tools covering every stage of document understanding, designed so that:

- You can pick the components appropriate to your problem (document type, quality, output need)
- You can swap any component for an alternative that better fits your constraints
- You always get a standard `ExtractionResult` at the end, regardless of which path was taken
- Downstream systems (pipelines, agents, APIs) consume `ExtractionResult` without knowing which tools processed the document

`docunderstand` is structured as a layered pipeline library. Each layer has a single responsibility and communicates through typed interfaces. Users can engage the full pipeline or drop into any individual layer.

```
┌─────────────────────────────────────────────────────────────────┐
│                          Public API                             │
│                docunderstand.pipeline.Pipeline                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
  ┌──────────┐    ┌────────────────┐   ┌──────────────┐
  │ Ingestor │    │ Preprocessor   │   │  Extractor   │
  │          │    │                │   │              │
  │ PDF/Image│    │ deskew/denoise │   │ Text+layout  │
  │  loading │    │ binarize/crop  │   │  + OCR       │
  └────┬─────┘    └───────┬────────┘   └──────┬───────┘
       │                  │                   │
       └──────────────────┼───────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  Canonical Document   │
              │       Graph           │
              │                       │
              │  artifacts[]          │
              │  transforms[]         │
              │  pages[]              │
              │  text_streams[]       │
              │  layout{}             │
              │    blocks / lines /   │
              │    tokens / tables /  │
              │    reading_order      │
              │  semantics{}          │
              │    entities / rels    │
              │  actions{}            │
              │    redactions         │
              │  telemetry{}          │
              └───────────┬───────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
  ┌────────────┐  ┌──────────────┐  ┌──────────────┐
  │ infoextract│  │   grounding  │  │   redactor   │
  │ (semantic) │  │ (anchors)    │  │ (actions)    │
  └────────────┘  └──────────────┘  └──────────────┘
```

---

## Package Layout

```
src/docunderstand/
├── __init__.py
├── main.py                  # CLI entry point
├── models/
│   ├── document.py          # All core dataclasses (see below)
│   └── extraction.py        # ExtractionResult, Field
├── ingest/
│   ├── base.py              # IngestorProtocol
│   ├── pdf.py               # Native PDF ingestion (PyMuPDF / pdfplumber)
│   └── image.py             # Raster image normalisation
├── preprocess/
│   ├── base.py              # PreprocessorProtocol
│   ├── pipeline.py          # Transform chain execution
│   ├── deskew.py
│   ├── denoise.py
│   ├── binarize.py
│   └── border.py
├── extract/
│   ├── base.py              # ExtractorProtocol
│   ├── native.py            # Text + coordinates from native PDF
│   └── ocr.py               # OCR backend (pluggable)
├── layout/
│   ├── base.py              # LayoutAnalyserProtocol
│   ├── heuristic.py         # Rule-based reading order and region detection
│   └── model.py             # ML-based layout (optional; layoutparser / docling)
├── structure/
│   ├── table.py             # Table detection and cell extraction
│   ├── keyvalue.py          # Key-value pairing (proximity-based)
│   └── selection_marks.py   # Checkbox / radio button detection
├── grounding/
│   ├── resolver.py          # Triple-anchor resolution
│   └── text_stream.py       # Canonical text stream assembly
├── actions/
│   ├── redaction.py         # Redaction object management
│   └── sanitize.py          # PDF content and metadata sanitization
├── telemetry/
│   └── spans.py             # OpenTelemetry span wrappers
└── pipeline/
    ├── pipeline.py          # Pipeline composition and execution
    └── steps.py             # Built-in step definitions
```

---

## Core Data Model

### Coordinate Space

All bounding regions are stored as **page-local normalised quads** — eight floats `[x0,y0, x1,y1, x2,y2, x3,y3]` in \[0,1\] space relative to page width and height. This is canonical. Axis-aligned bounding boxes are cached derivatives only and must never be used as the authoritative source for redaction. Page width, height, and DPI metadata are preserved to enable deterministic round-trips back to pixel or PDF user-space coordinates.

```python
@dataclass(frozen=True)
class Quad:
    x0: float; y0: float   # top-left
    x1: float; y1: float   # top-right
    x2: float; y2: float   # bottom-right
    x3: float; y3: float   # bottom-left
    page_id: str

    @property
    def bbox(self) -> BBox: ...  # cached AABB, not canonical
```

### Artifacts and Transforms

Preprocessing lineage is first-class. Every derived image (rendered page, deskewed page, binarized page) is an `Artifact`. Every operation that produced it is a `Transform`.

```python
@dataclass
class Artifact:
    id: str                  # e.g. "a1:p1" (rendered page 1)
    role: str                # source_document | rendered_page | preprocessed_page
    page_id: str | None
    parent_ids: list[str]
    mime_type: str
    sha256: str | None
    width_px: int | None
    height_px: int | None
    dpi: int | None

@dataclass
class Transform:
    id: str                  # e.g. "tr:deskew:p1"
    stage: str               # deskew | binarize | denoise | render_pdf | …
    input_artifact_ids: list[str]
    output_artifact_ids: list[str]
    params: dict[str, Any]
    quality: dict[str, Any]  # blur_laplacian, skew_angle_deg, border_dark_ratio …
    telemetry: dict[str, Any] # duration_ms
```

### Text Streams

The canonical text stream is the stable backbone for provenance. Every token's `span` references a character-level offset in this stream, making anchors resilient to tokenisation drift across OCR engine versions.

```python
@dataclass
class TextStream:
    id: str                  # e.g. "ts:doc"
    span_unit: str           # "grapheme" | "token"
    text: str                # full reading-order text of the document
```

### Token

```python
@dataclass
class Token:
    id: str
    page_id: str
    line_id: str
    block_id: str
    text: str
    span: TextSpan            # {stream_id, start, end}
    regions: list[Quad]       # per-page quads (usually one)
    ocr: OCRMeta | None       # engine, confidence, raw_confidence, text_type

@dataclass
class OCRMeta:
    engine: str               # "tesseract" | "paddleocr" | …
    confidence: float         # normalised [0,1]
    raw_confidence: float
    raw_confidence_scale: str # "0-1" | "0-100"
    text_type: str            # "printed" | "handwritten" | "unknown"
```

### Region and Block

```python
@dataclass
class Block:
    id: str
    page_id: str
    role: BlockRole           # PARAGRAPH | TITLE | HEADING | PAGE_HEADER |
                              # PAGE_FOOTER | PAGE_NUMBER | FOOTNOTE |
                              # FIGURE | TABLE | SELECTION_MARK | SIGNATURE
    regions: list[Quad]
    reading_order_index: int
    confidence: float
    language: str | None
    reading_direction: str | None   # "ltr" | "rtl" | "ttb"
```

### Triple Anchor

Every semantic entity anchor stores all three reference types. This makes anchors robust to tokenisation changes, coordinate system shifts, and cross-page mentions.

```python
@dataclass
class Anchor:
    token_ids: list[str]
    text_spans: list[TextSpan]         # [{stream_id, start, end}]
    page_regions: list[PageRegion]     # [{page_id, quad}]
```

### DocumentPage and ExtractionResult

```python
@dataclass
class DocumentPage:
    id: str
    page_number: int
    width_px: int
    height_px: int
    dpi: int
    coord_space: str            # "normalized_quad"
    text_stream_id: str
    image: bytes | None         # raw PNG bytes

@dataclass
class ExtractionResult:
    doc_id: str
    version: str
    source: SourceMeta
    artifacts: list[Artifact]
    transforms: list[Transform]
    pages: list[DocumentPage]
    text_streams: list[TextStream]
    layout: LayoutLayer         # blocks, lines, tokens, glyphs, tables, cells, reading_order
    semantics: SemanticsLayer   # entities, relations
    actions: ActionsLayer       # redactions
    telemetry: TelemetryLayer
```

---

## Canonical Schema (JSON)

The full wire format is defined in `docs/reference/schema.md`. Key structural decisions:

- `doc_id` is `doc:sha256:<hash>` — deterministic and content-addressed
- All IDs are scoped: `"p1"`, `"b1"`, `"l1"`, `"t1"`, `"a1:p1"`, `"tr:deskew:p1"`, `"e1"`, `"r1"`
- `confidence` is always normalised \[0,1\]; `raw_confidence` and `raw_confidence_scale` preserved alongside it
- Geometry is always `regions: [{quad: [...8 floats...]}]` — never a bare `bbox`
- Actions reference entities by `entity_id` and carry their own `regions[]` — resolved at action time, not inherited from the entity

---

## Package Boundaries

```
docunderstand          Perception layer
  ingest               Source loading, rendering, artifact creation
  preprocess           Transform chain (deskew, denoise, binarize, crop)
  extract              Text + coordinates (native PDF or OCR)
  layout               Region detection, structural role labelling, reading order
  structure            Table parsing, key-value detection, selection marks
  grounding            Triple-anchor assembly, text-stream construction
  actions              Redaction objects, PDF sanitization

infoextract            Semantic layer (consumes ExtractionResult)
  classify             Document type classification
  extract_entities     Named entity recognition, business field extraction
  align                Ontology alignment, schema mapping
  graph                Knowledge graph projection

grounding              Anchor resolution service (shared)
  resolver             token_ids + text_spans + page_regions per entity

redactor               Action execution service
  renderer             Raster mask burn-in, native PDF redaction, metadata sanitize
  verifier             Post-redaction verification pass
```

This is consistent with how production APIs decompose: Textract's Block relationships, Document Intelligence's reading-order spans, and Document AI's text and page anchors are all perception-layer outputs that semantic systems consume.

---

## Pipeline Execution Model

```python
from docunderstand import Pipeline
from docunderstand.ingest import PDFIngestor
from docunderstand.preprocess import StandardPreprocessor
from docunderstand.extract import NativeExtractor
from docunderstand.layout import HeuristicLayoutAnalyser
from docunderstand.structure import TableExtractor, KeyValueExtractor
from docunderstand.grounding import TripleAnchorResolver

pipeline = Pipeline([
    PDFIngestor(),
    StandardPreprocessor(),          # no-op for native PDFs; full chain for scans
    NativeExtractor(),               # or OCRExtractor() for scans
    HeuristicLayoutAnalyser(),       # or ModelLayoutAnalyser() for complex layouts
    TableExtractor(),
    KeyValueExtractor(schema=MyFormSchema),
    TripleAnchorResolver(),
])

result: ExtractionResult = pipeline.run("path/to/document.pdf")
```

Steps are composable: swap any stage for an alternative implementation that satisfies the same `Protocol`.

---

## Backend Protocols

```python
class IngestorProtocol(Protocol):
    def load(self, path: Path) -> ExtractionResult: ...

class PreprocessorProtocol(Protocol):
    def process(self, result: ExtractionResult) -> ExtractionResult: ...

class ExtractorProtocol(Protocol):
    def extract(self, result: ExtractionResult) -> ExtractionResult: ...

class LayoutAnalyserProtocol(Protocol):
    def analyse(self, result: ExtractionResult) -> ExtractionResult: ...
```

Each stage returns a new (or mutated) `ExtractionResult`, appending artifacts, transforms, layout objects, and telemetry as it goes.

---

## Grounding and Redaction

### Triple-anchor resolution

The resolver follows a precedence policy:

1. Use `token_ids` / `glyph_ids` when they exist — most precise
2. Fall back to `text_span` against the canonical text stream when tokenisation shifts between engine versions
3. Recover page-local quads per page; keep disjoint shapes separate unless genuinely adjacent in the same line or cell
4. Only at render time convert normalised page-space geometry to pixels or PDF user-space; apply padding rendering-aware

### Redaction — PDF vs. raster

| Document type | Required approach |
|---|---|
| Born-digital PDF | Apply native PDF redaction objects, remove underlying content objects, sanitize metadata and attachments, run rasterized verification pass |
| Scanned image PDF | Burn masks into page image layer, sanitize metadata and attachments at container level |
| Raster image | Render masks over resolved regions, burn into image |

Drawing black rectangles over a PDF is not redaction — the underlying text stream remains present and accessible. The PDF Association makes this explicit: a PDF that still contains redaction annotations is an incomplete workflow.

---

## Telemetry

Every pipeline stage is modelled as an OpenTelemetry span. Resource attributes (workflow version, model versions, code revision, tenant, document hash) travel on the root span. Stage spans carry per-stage attributes.

### Stage spans

| Span name | Key attributes |
|---|---|
| `ingest` | mime_type, sha256, page_count, source_class |
| `render_page` | page_id, dpi, width_px, height_px, renderer, alpha_present |
| `preprocess_page` | page_id, transform_ids, skew_angle_deg, blur_laplacian, border_dark_ratio |
| `segment_page` | page_id, block_count, line_count, orphan_region_count |
| `recognize_region` | page_id, ocr_engine, mean_token_confidence, low_conf_token_ratio, text_type_distribution |
| `assemble_text_stream` | stream_id, token_count, language_distribution |
| `extract_semantics` | entity_count, unresolved_anchor_count |
| `resolve_grounding` | entity_count, multi_region_entity_rate, unresolved_count |
| `apply_redaction` | redaction_count, mask_area_ratio, modes_used |
| `verify_output` | verification_failures, sanitize_result |

### Quality signal groups

- **Preprocessing**: blur (Laplacian variance), skew angle, dewarp magnitude, border-darkness ratio, binarization method + threshold, denoise applied
- **OCR / text**: mean + median token confidence, low-confidence token ratio, printed-vs-handwritten share, language/script distribution; CER/WER/Bag-of-Words error when ground truth available
- **Layout**: block/line/token/table/cell counts, orphan region count, reading-order confidence, polygon vertex counts, unresolved region references
- **Actions**: redaction count by entity type, unresolved action count, mask area ratio, verification failures

---

## Integration with infoextract

`docunderstand` produces; `infoextract` consumes.

```
infoextract                         docunderstand
───────────                         ─────────────
DocumentSource ──(bytes/path)──►    Pipeline
                                    └── ExtractionResult
                                          layout layer
                                          text streams
                                          triple anchors
                     ◄──────────────────────────────────
infoextract appends semantics layer (entities, relations)
grounding service resolves anchors back to page regions
redactor executes actions against source artifacts
```

The `ExtractionResult` is the shared contract. `infoextract` never mutates the layout layer — it appends to `semantics{}`. The grounding service never mutates `semantics{}` — it resolves `anchors{}` on demand. The redactor consumes `actions{}` plus source artifacts and returns a new artifact, preserving the original.

---

## Optional Extras

| Extra | Capabilities unlocked |
|---|---|
| `[ocr]` | Tesseract and PaddleOCR OCR backends |
| `[layout]` | ML-based layout analysis (layoutparser, docling) |
| `[dev]` | pytest, ruff, mypy, bandit, pre-commit |
| `[docs]` | MkDocs Material site build |
