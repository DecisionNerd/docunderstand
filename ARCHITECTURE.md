# Architecture

## Overview

`docunderstand` is structured as a layered pipeline library. Each layer has a single responsibility and communicates with adjacent layers through typed interfaces. Users can engage the full pipeline or drop into any individual layer.

```
┌─────────────────────────────────────────────────────────────┐
│                        Public API                           │
│              docunderstand.pipeline.Pipeline                │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
   ┌──────────┐   ┌────────────┐   ┌──────────────┐
   │ Ingestor │   │ Extractor  │   │  Structurer  │
   │          │   │            │   │              │
   │ PDF/Image│   │ Text+Layout│   │ KV / Tables  │
   │  loading │   │  + OCR     │   │  / Entities  │
   └────┬─────┘   └─────┬──────┘   └──────┬───────┘
        │               │                 │
        └───────────────┼─────────────────┘
                        │
                        ▼
               ┌─────────────────┐
               │  DocumentPage   │  (core data model)
               │  tokens: list   │
               │  regions: list  │
               │  tables: list   │
               └─────────────────┘
```

---

## Package Layout

```
src/docunderstand/
├── __init__.py          # Public re-exports
├── main.py              # CLI entry point
├── models/
│   ├── document.py      # DocumentPage, Token, Region, Table, Cell
│   └── extraction.py    # ExtractionResult, Field, KeyValuePair
├── ingest/
│   ├── base.py          # Ingestor protocol
│   ├── pdf.py           # Native PDF ingestion (pdfplumber / PyMuPDF)
│   └── image.py         # Raster image normalisation
├── extract/
│   ├── base.py          # Extractor protocol
│   ├── native.py        # Text + coordinates from native PDF
│   └── ocr.py           # OCR backend (pluggable: tesseract, paddleocr)
├── layout/
│   ├── base.py          # LayoutAnalyser protocol
│   ├── heuristic.py     # Rule-based reading order and region detection
│   └── model.py         # ML-based layout (optional; layoutparser / docling)
├── structure/
│   ├── table.py         # Table detection and cell extraction
│   ├── keyvalue.py      # Key-value pairing (proximity-based)
│   └── entities.py      # Named entity extraction
└── pipeline/
    ├── pipeline.py      # Pipeline composition and execution
    └── steps.py         # Built-in step definitions
```

---

## Core Data Model

### `Token`

The atomic unit of extracted content. Represents a single word (or OCR word-box).

```python
@dataclass
class Token:
    text: str
    bbox: BoundingBox        # normalised [0,1] coordinates
    confidence: float        # 1.0 for native PDF; OCR confidence otherwise
    page: int
```

### `BoundingBox`

```python
@dataclass
class BoundingBox:
    x0: float   # left edge,  normalised [0,1]
    y0: float   # top edge,   normalised [0,1]
    x1: float   # right edge, normalised [0,1]
    y1: float   # bottom edge, normalised [0,1]
```

### `Region`

A detected layout region (text block, table area, figure, header, footer).

```python
@dataclass
class Region:
    kind: RegionKind         # TEXT | TABLE | FIGURE | HEADER | FOOTER
    bbox: BoundingBox
    tokens: list[Token]
    reading_order: int
```

### `DocumentPage`

The central object passed between pipeline stages.

```python
@dataclass
class DocumentPage:
    page_number: int
    width_px: int
    height_px: int
    tokens: list[Token]
    regions: list[Region]
    tables: list[Table]
    image: bytes | None      # raw PNG bytes, if available
```

### `ExtractionResult`

Final structured output returned to the caller.

```python
@dataclass
class ExtractionResult:
    pages: list[DocumentPage]
    fields: list[Field]      # extracted key-value fields
    tables: list[Table]
    metadata: dict[str, Any]
```

---

## Pipeline Execution Model

Pipelines are defined as ordered sequences of steps. Each step receives a `DocumentPage` (or list thereof) and returns a modified or annotated version.

```python
from docunderstand import Pipeline
from docunderstand.ingest import PDFIngestor
from docunderstand.extract import NativeExtractor
from docunderstand.layout import HeuristicLayoutAnalyser
from docunderstand.structure import KeyValueExtractor

pipeline = Pipeline([
    PDFIngestor(),
    NativeExtractor(),
    HeuristicLayoutAnalyser(),
    KeyValueExtractor(schema=MyFormSchema),
])

result = pipeline.run("path/to/document.pdf")
```

Steps are composable: replace `NativeExtractor` with `OCRExtractor` for scanned documents, or `HeuristicLayoutAnalyser` with `ModelLayoutAnalyser` for complex layouts.

---

## Backend Protocols

All major components are defined as Python `Protocol` classes so users can substitute their own implementations without subclassing:

```python
class IngestorProtocol(Protocol):
    def load(self, path: Path) -> list[DocumentPage]: ...

class ExtractorProtocol(Protocol):
    def extract(self, page: DocumentPage) -> DocumentPage: ...

class LayoutAnalyserProtocol(Protocol):
    def analyse(self, page: DocumentPage) -> DocumentPage: ...
```

---

## Coordinate System

All bounding boxes are normalised to `[0.0, 1.0]` relative to page width and height. This ensures coordinates are consistent regardless of document resolution or render scale. Raw pixel coordinates from PDF or OCR sources are normalised during ingestion.

---

## Optional Extras

| Extra | Capabilities unlocked |
|---|---|
| `[ocr]` | Tesseract and PaddleOCR backends |
| `[layout]` | ML-based layout analysis via layoutparser / docling |
| `[dev]` | pytest, ruff, mypy, bandit, pre-commit |
| `[docs]` | MkDocs Material site build |

---

## Integration with infoextract

`docunderstand` is downstream of `infoextract`. The intended integration point is `ExtractionResult`: infoextract orchestrates document retrieval and routes documents to docunderstand pipelines, consuming `ExtractionResult` objects to populate extraction schemas.

```
infoextract                   docunderstand
────────────                  ─────────────
DocumentSource  ──(bytes)──►  Pipeline
                              └── ExtractionResult  ──►  Extraction schema
```
