# docunderstand

**The Python workbench for visually rich document understanding.**

[![PyPI](https://img.shields.io/pypi/v/docunderstand.svg)](https://pypi.org/project/docunderstand/)
[![Python](https://img.shields.io/pypi/pyversions/docunderstand.svg)](https://pypi.org/project/docunderstand/)
[![Tests](https://github.com/DecisionNerd/docunderstand/workflows/CI/badge.svg)](https://github.com/DecisionNerd/docunderstand/actions)
[![Coverage](https://codecov.io/gh/DecisionNerd/docunderstand/graph/badge.svg)](https://codecov.io/gh/DecisionNerd/docunderstand)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/DecisionNerd/docunderstand/blob/main/LICENSE)

---

## The problem

VRDU problems do not all look the same. A born-digital invoice is trivial to parse natively. A scanned government form from the 1970s needs deskewing, OCR, and a trained extraction model. A contract with complex multi-column layout needs a layout model and cross-page entity resolution. A photo of a receipt taken on a phone needs preprocessing before any OCR backend will work reliably.

There is no single right approach. The right approach depends on the document type, quality, layout complexity, and what you need out of it.

---

## What docunderstand is

`docunderstand` is not a single pipeline. It is a workbench — a collection of composable tools covering every stage of VRDU processing, with:

- **A common interface** across all components, so you can swap backends without rewriting downstream code
- **All the tools in one place** — ingestion, preprocessing, OCR, layout analysis, table parsing, key-value extraction, grounding, redaction
- **A standard output** — `ExtractionResult` — regardless of which path was taken, so downstream pipelines and agents always see the same shape

```python
from docunderstand import Pipeline
from docunderstand.ingest import PDFIngestor
from docunderstand.preprocess import StandardPreprocessor
from docunderstand.extract import OCRExtractor
from docunderstand.layout import ModelLayoutAnalyser
from docunderstand.structure import KeyValueExtractor

pipeline = Pipeline([
    PDFIngestor(),
    StandardPreprocessor(),        # deskew → denoise → binarize
    OCRExtractor(backend="tesseract"),
    ModelLayoutAnalyser(),
    KeyValueExtractor(schema=MyFormSchema),
])

result = pipeline.run("scanned_form.pdf")
# result: ExtractionResult — same shape whether the input
# was a clean PDF or a 50-year-old scanned form
```

---

## Standard output

Every pipeline produces an `ExtractionResult`: a canonical document graph with:

- **Artifact and transform lineage** — every preprocessing step recorded
- **Layout layer** — tokens, lines, blocks, tables, structural roles, reading order
- **Semantics layer** — entities and relations with triple anchors (token IDs + text-stream spans + page polygons)
- **Actions layer** — redactions with resolved polygon regions
- **Telemetry** — per-page quality signals, confidence, warnings, timing

The same structure whether you used native PDF extraction, Tesseract, PaddleOCR, LayoutLM, or Donut. Downstream pipelines and agentic workflows consume `ExtractionResult` without knowing which tools processed the document.

---

## Navigation

**New to VRDU?**

Start with the [VRDU Research](vrdu/index.md) section — it explains the problem space, key tasks, available datasets, models, and the Python ecosystem before diving into the library.

| | |
|---|---|
| [What is VRDU?](vrdu/index.md) | The problem space and three modalities |
| [Datasets](vrdu/datasets.md) | FUNSD, CORD, DocVQA, Google VRDU benchmark, and more |
| [Models](vrdu/models.md) | LayoutLM, Donut, Nougat, TrOCR, and when to use each |
| [Ecosystem](vrdu/ecosystem.md) | pdfplumber, PyMuPDF, PaddleOCR, docling, unstructured |
| [Pipeline Architecture](vrdu/pipeline.md) | Standard stages and design decisions |

**Ready to use the library?**

| | |
|---|---|
| [Installation](getting-started/installation.md) | Install via pip or uv |
| [Quick Start](getting-started/quickstart.md) | Your first pipeline in five minutes |
| [User Guide](guide/overview.md) | Library concepts and component model |

**Reference**

| | |
|---|---|
| [Canonical Schema](reference/schema.md) | The ExtractionResult wire format |
| [API Reference](reference/api.md) | Python API documentation |
| [Requirements](reference/requirements.md) | Functional and non-functional requirements |
| [Architecture](reference/architecture.md) | Package design, data model, boundary decisions |

---

## Design principles

1. **Workbench, not prescription** — give you the tools to solve the problem you have, not force you into one pipeline
2. **Standard output, varied input** — `ExtractionResult` is stable regardless of which backends processed the document
3. **Composable** — swap any component at any stage; every interface is a `Protocol`
4. **Grounded** — every extracted value traces back to its source pixels via triple anchors
5. **Auditable** — provenance, confidence, preprocessing lineage, and telemetry throughout
6. **Perception only** — owns layout, structure, and grounding; leaves business semantics to infoextract
