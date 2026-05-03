# Visually Rich Document Understanding

**Visually Rich Document Understanding (VRDU)** is the task of automatically extracting, analysing, and structuring information from documents where spatial layout carries meaning alongside textual content.

Unlike plain-text NLP, VRDU operates on the principle that *how* a document is arranged — field positions, table structure, column alignment, reading order — is as semantically significant as *what* it says.

---

## The Core Problem

Traditional OCR extracts text but discards spatial context. Consider an invoice:

```
Invoice #    INV-2024-0042
Date         2024-11-15
Bill To      Acme Corp
Amount Due   $4,200.00
```

A pure text extraction returns a flat string. To know that `INV-2024-0042` is the invoice number and not the date, you need the spatial relationship between label and value. VRDU systems preserve and reason over that structure.

---

## Three Information Modalities

VRDU models integrate three sources of signal:

| Modality | What it captures | Examples |
|---|---|---|
| **Text** | Token content from OCR or native extraction | Words, numbers, punctuation |
| **Layout** | Spatial position and size of tokens/regions | Bounding boxes, reading order |
| **Visual** | Pixel-level appearance of the page | Fonts, rules, shading, logos |

Early approaches used only text. Modern models (LayoutLM family, Donut) fuse all three.

---

## The Perception / Semantics Boundary

A production VRDU system should split responsibilities cleanly:

- **Perception layer** (`docunderstand`) — where is the text, what structural role does it play, and how does it map back to pixels?
- **Semantics layer** (`infoextract`) — what does it mean, what business entities does it contain, how does it align to an ontology?

This mirrors how cloud document platforms are built. Google Document AI emits layout units with text anchors and bounding polygons, then exposes entities with page anchors separately. Amazon Textract emits Block objects with geometry and relationships, then exposes key-value and table structure as a second pass. Microsoft Document Intelligence emits a reading-order content string with bounding regions, then layers structured field extraction on top.

The perception layer must own **document-intrinsic structural roles** — header, footer, page number, title, paragraph, table, selection mark, signature, reading order, reading direction, language/script — because these are layout facts, not business ontology decisions.

---

## Grounded Extraction and Redaction

Grounding is the process of tying semantic claims back to the source document: which token, which character offset, which page region. For extraction, grounding enables human review and auditability. For redaction, it is mandatory — you cannot safely redact a document unless you know exactly which pixels carry the sensitive content.

A robust anchor representation stores all three reference types per entity:

1. **Token / glyph IDs** — precise within the current extraction
2. **Text-stream spans** — stable character offsets in a canonical reading-order string; survives tokenisation drift across OCR engine versions
3. **Page-local polygon regions** — the final source for render-time redaction geometry; an array, not a single box, because entities can span multiple lines or pages

See [Pipeline Architecture](pipeline.md) and the [Canonical Schema](../reference/schema.md) for the full data contract.

---

## Key Tasks

- **Layout Analysis** — detecting regions, reading order, document hierarchy
- **Information Extraction** — key-value fields, named entities, amounts, dates
- **Table Detection and Parsing** — locating tables and extracting cell structure
- **Document Classification** — routing documents to appropriate extraction pipelines
- **Document Question Answering** — answering natural language questions over document content

See [Pipeline Architecture](pipeline.md) for how these tasks fit together.

---

## Document Types

VRDU is most valuable for documents where layout is load-bearing:

- **Forms** — insurance claims, loan applications, tax documents
- **Invoices** — itemised transactions, line items, totals
- **Receipts** — retail and service transaction records
- **Contracts** — legal documents with hierarchical clause structure
- **Scientific papers** — multi-column layouts, equations, cross-references
- **Tables** — any document containing structured data grids

---

## Further Reading

- [Datasets](datasets.md) — FUNSD, CORD, SROIE, DocVQA, PubLayNet, VRDU benchmark
- [Models and Methods](models.md) — LayoutLM, Donut, TrOCR, Nougat, DiT
- [Python Ecosystem](ecosystem.md) — pdfplumber, PyMuPDF, PaddleOCR, unstructured, docling
- [Pipeline Architecture](pipeline.md) — standard VRDU pipeline stages
