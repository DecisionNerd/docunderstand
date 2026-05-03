# VRDU Datasets

Key benchmarks and datasets for training and evaluating visually rich document understanding systems.

---

## Form Understanding

### FUNSD

**Form Understanding in Noisy Scanned Documents**

- 149 real-world scanned form images with full token-level annotations
- Labels: `header`, `question`, `answer`, `other`
- Task: semantic entity labelling and key-value linking
- Widely used as the standard benchmark for form field extraction
- [Paper](https://arxiv.org/abs/1905.13538) — Jaume et al., 2019

### CORD

**Consolidated Receipt Dataset**

- ~10,000 receipt images from Southeast Asian merchants
- Annotations: item-level fields (name, price, quantity), totals, store info
- Task: receipt understanding and structured extraction
- [GitHub](https://github.com/clovaai/cord)

### SROIE

**Scanned Receipts OCR and Information Extraction**

- ~1,000 receipt images
- Tasks: text localisation, OCR, and extraction of 4 fields (company, date, address, total)
- Originally an ICDAR 2019 competition dataset
- [Competition](https://rrc.cvc.uab.es/?ch=13)

### Google VRDU Benchmark

Google's benchmark specifically targeting form understanding, with two complementary tasks:

- **Ad-hoc extraction** — given a natural language query (e.g. "What is the policy number?"), extract the corresponding value from the form image. Tests layout-aware retrieval.
- **Template-based extraction** — given a predefined set of fields for a known form type, extract all field values. Tests structured, schema-driven understanding.

The benchmark emphasises real-world challenges: varying form layouts, handwritten vs. printed content, and mixed-quality scans.

---

## Document Question Answering

### DocVQA

- ~12,000 document images with 50,000+ question-answer pairs
- Documents: industry reports, memos, letters, tables
- Tasks: answer extraction from document images
- The primary benchmark for document-level visual QA
- [Website](https://www.docvqa.org/)

### MP-DocVQA

**Multi-Page Document VQA**

- Extension of DocVQA requiring reasoning across multiple pages
- Tests long-document understanding and evidence aggregation
- [Paper](https://arxiv.org/abs/2212.05935)

### DUDE

**Document Understanding Dataset and Evaluation**

- Large-scale, diverse document types (contracts, forms, reports, books)
- Rich annotations including unanswerable questions and multi-span answers
- [Paper](https://arxiv.org/abs/2305.08455)

---

## Layout Analysis

### PubLayNet

- ~360,000 academic paper page images
- Annotations: text, title, list, figure, table regions (bounding boxes + polygon masks)
- Task: document layout detection
- [GitHub](https://github.com/ibm-aur-nlp/PubLayNet)

### DocLayNet

- ~80,000 pages from 6 document categories (financial, scientific, patents, etc.)
- Richer label set than PubLayNet (11 classes)
- [Paper](https://arxiv.org/abs/2206.01062)

---

## Document Classification

### RVL-CDIP

**Ryerson Vision Lab Complex Document Information Processing**

- ~400,000 grayscale document images, 16 classes
- Classes: letter, memo, email, filefolder, form, handwritten, invoice, advertisement, budget, news, presentation, scientific report, scientific publication, specification, questionnaire, resume
- Standard benchmark for document classification
- [Paper](https://dl.acm.org/doi/10.1145/2756406.2756452)

---

## Dataset Summary

| Dataset | Size | Task | Document Type |
|---|---|---|---|
| FUNSD | 149 docs | Entity labelling, KV linking | Forms |
| CORD | 10k images | Structured extraction | Receipts |
| SROIE | 1k images | OCR + field extraction | Receipts |
| Google VRDU | — | Ad-hoc + template extraction | Forms |
| DocVQA | 12k images | Visual QA | Mixed |
| MP-DocVQA | — | Multi-page QA | Multi-page |
| DUDE | Large | Open-domain DocQA | Mixed |
| PubLayNet | 360k pages | Layout detection | Academic papers |
| DocLayNet | 80k pages | Layout detection | Mixed |
| RVL-CDIP | 400k images | Classification | Mixed (16 classes) |
