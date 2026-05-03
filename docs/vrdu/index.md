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
