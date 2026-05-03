# docunderstand

**The Python workbench for visually rich document understanding.**

Given a VRDU problem, `docunderstand` helps you choose the right tools, compose them into a pipeline, and produce a standard output that downstream systems — pipelines, agents, APIs — can consume without knowing how the document was processed.

---

## What this is

VRDU problems come in many shapes. A born-digital invoice is trivial to extract natively. A stack of scanned government forms from the 1970s needs deskewing, OCR, and a trained extraction model. A contract needs layout analysis, reading order, and cross-page entity resolution. A photo of a receipt taken on a phone needs preprocessing, binarization, and a different OCR backend than a clean scan.

There is no single right approach. There are:

- Multiple document types, each with different structure and quality characteristics
- Multiple extraction backends (native PDF, Tesseract, PaddleOCR, LayoutLM, Donut, cloud APIs)
- Multiple downstream needs (structured JSON, redaction, RAG ingestion, agentic tool use)

`docunderstand` gives you all of those tools in one place, with a common interface so you can swap components, and a standard `ExtractionResult` at the end no matter which path you took.

---

## Core idea

```python
from docunderstand import Pipeline
from docunderstand.ingest import PDFIngestor
from docunderstand.extract import NativeExtractor, OCRExtractor
from docunderstand.layout import HeuristicLayoutAnalyser
from docunderstand.structure import KeyValueExtractor

# Born-digital invoice — native path
pipeline = Pipeline([
    PDFIngestor(),
    NativeExtractor(),
    HeuristicLayoutAnalyser(),
    KeyValueExtractor(schema=InvoiceSchema),
])

# Scanned 1970s form — OCR path, same output shape
pipeline = Pipeline([
    PDFIngestor(),
    StandardPreprocessor(),   # deskew, denoise, binarize
    OCRExtractor(backend="tesseract"),
    ModelLayoutAnalyser(),
    KeyValueExtractor(schema=FormSchema),
])

result = pipeline.run("document.pdf")
# result is always an ExtractionResult — same shape, regardless of path
```

The output is always an `ExtractionResult`: a canonical document graph with layout, entities, and actions, grounded back to the source pixels. Downstream code doesn't need to know which path was taken.

---

## What it covers

- **Ingestion** — PDF (native and scanned), raster images
- **Preprocessing** — deskew, dewarp, denoise, binarize, border clean (with explicit lineage)
- **Text extraction** — native PDF text or pluggable OCR (Tesseract, PaddleOCR)
- **Layout analysis** — region detection, structural roles, reading order (heuristic or model-based)
- **Table parsing** — structure extraction, merged cells, cell-level text
- **Key-value extraction** — form fields, proximity-based and schema-driven
- **Selection marks** — checkboxes, radio buttons
- **Entity grounding** — triple anchors: token IDs + text-stream spans + page-local polygons
- **Redaction** — raster burn-in and native PDF redaction with content removal
- **Standard output** — `ExtractionResult` with provenance, confidence, and telemetry throughout

---

## Installation

```bash
pip install docunderstand
# or
uv add docunderstand
```

Optional extras:

```bash
pip install "docunderstand[ocr]"      # Tesseract + PaddleOCR backends
pip install "docunderstand[layout]"   # ML layout models (layoutparser, docling)
pip install "docunderstand[docs]"     # MkDocs site build
```

---

## Companion library

`docunderstand` is the perception layer. Its `ExtractionResult` is consumed by [infoextract](https://github.com/DecisionNerd/infoextract), which handles business semantics: entity classification, ontology alignment, and knowledge graph construction.

---

## Documentation

Full documentation at [decisionnerd.github.io/docunderstand](https://decisionnerd.github.io/docunderstand/).

- [Getting Started](https://decisionnerd.github.io/docunderstand/getting-started/installation/)
- [User Guide](https://decisionnerd.github.io/docunderstand/guide/overview/)
- [VRDU Research](https://decisionnerd.github.io/docunderstand/vrdu/)
- [Canonical Schema](https://decisionnerd.github.io/docunderstand/reference/schema/)
- [Architecture](https://decisionnerd.github.io/docunderstand/reference/architecture/)
