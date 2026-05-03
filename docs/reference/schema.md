# Canonical Document Schema

The `ExtractionResult` is the shared contract between `docunderstand` (perception layer) and downstream consumers (`infoextract`, `grounding`, `redactor`). It is an append-only canonical document graph with immutable IDs and separate layers for layout, semantics, and actions.

---

## Top-level structure

```json
{
  "doc_id": "doc:sha256:<hex>",
  "version": "1.0",
  "source": { ... },
  "artifacts": [ ... ],
  "transforms": [ ... ],
  "pages": [ ... ],
  "text_streams": [ ... ],
  "layout": { ... },
  "semantics": { ... },
  "actions": { ... },
  "telemetry": { ... }
}
```

---

## `source`

```json
{
  "mime_type": "application/pdf",
  "sha256": "<hex>",
  "page_count": 12,
  "ingested_at": "2026-05-03T12:00:00Z",
  "source_class": "born_digital_pdf"
}
```

`source_class` is one of: `born_digital_pdf`, `scanned_pdf`, `raster_image`, `camera_image`.

---

## `artifacts`

Each artifact is an immutable versioned representation of a page image — source, rendered, or preprocessed.

```json
[
  {
    "id": "a0",
    "role": "source_document",
    "mime_type": "application/pdf",
    "sha256": "<hex>",
    "page_id": null,
    "parent_ids": []
  },
  {
    "id": "a1:p1",
    "role": "rendered_page",
    "page_id": "p1",
    "parent_ids": ["a0"],
    "width_px": 2550,
    "height_px": 3300,
    "dpi": 300
  },
  {
    "id": "a2:p1",
    "role": "preprocessed_page",
    "page_id": "p1",
    "parent_ids": ["a1:p1"]
  }
]
```

Roles: `source_document` · `rendered_page` · `preprocessed_page` · `region_crop` · `word_crop`

---

## `transforms`

Each transform records one preprocessing or rendering operation with its parameters and quality signals.

```json
[
  {
    "id": "tr:render:p1",
    "stage": "render_pdf",
    "input_artifact_ids": ["a0"],
    "output_artifact_ids": ["a1:p1"],
    "params": { "dpi": 300, "renderer": "pdfium", "color_mode": "rgb" },
    "quality": { "alpha_present": false },
    "telemetry": { "duration_ms": 22 }
  },
  {
    "id": "tr:deskew:p1",
    "stage": "deskew",
    "input_artifact_ids": ["a1:p1"],
    "output_artifact_ids": ["a2:p1"],
    "params": { "angle_deg": -0.82 },
    "quality": { "blur_laplacian": 146.7, "border_dark_ratio": 0.013 },
    "telemetry": { "duration_ms": 4 }
  }
]
```

Standard stage names: `render_pdf` · `border_clean` · `deskew` · `dewarp` · `denoise` · `alpha_remove` · `contrast_normalise` · `binarize`

---

## `pages`

```json
[
  {
    "id": "p1",
    "page_number": 1,
    "coord_space": "normalized_quad",
    "width_px": 2550,
    "height_px": 3300,
    "dpi": 300,
    "image_resolution_unit": "ppi",
    "text_stream_id": "ts:doc"
  }
]
```

`coord_space` is always `"normalized_quad"`. All geometry in the document is in \[0,1\] page-local space.

---

## `text_streams`

```json
[
  {
    "id": "ts:doc",
    "span_unit": "grapheme",
    "text": "John Smith SSN 123-45-6789 ..."
  }
]
```

The canonical text stream assembles all document text in reading order. Character offsets in this stream are the stable anchor for all `TextSpan` references.

---

## `layout`

### `blocks`

```json
{
  "id": "b1",
  "page_id": "p1",
  "role": "paragraph",
  "regions": [{ "quad": [0.10, 0.20, 0.45, 0.20, 0.45, 0.25, 0.10, 0.25] }],
  "reading_order_index": 12,
  "confidence": 0.97,
  "language": "en",
  "reading_direction": "ltr"
}
```

Block roles: `paragraph` · `title` · `section_heading` · `page_header` · `page_footer` · `page_number` · `footnote` · `figure` · `table` · `selection_mark` · `signature`

### `tokens`

```json
{
  "id": "t1",
  "page_id": "p1",
  "line_id": "l1",
  "block_id": "b1",
  "text": "123-45-6789",
  "span": { "stream_id": "ts:doc", "start": 15, "end": 26 },
  "regions": [{ "quad": [0.30, 0.20, 0.40, 0.20, 0.40, 0.22, 0.30, 0.22] }],
  "ocr": {
    "engine": "tesseract",
    "confidence": 0.98,
    "raw_confidence": 97.2,
    "raw_confidence_scale": "0-100",
    "text_type": "printed"
  }
}
```

`confidence` is always normalised \[0,1\]. `raw_confidence` and `raw_confidence_scale` are preserved for auditability.

### `reading_order`

```json
[
  { "from": "b1", "to": "b2", "relation": "next", "confidence": 0.93 }
]
```

---

## `semantics`

### `entities`

Entities carry a **triple anchor** — all three reference types must be present:

```json
{
  "id": "e1",
  "type": "ssn",
  "mention_text": "123-45-6789",
  "normalized_value": "123456789",
  "anchors": {
    "token_ids": ["t1"],
    "text_spans": [{ "stream_id": "ts:doc", "start": 15, "end": 26 }],
    "page_regions": [
      { "page_id": "p1", "quad": [0.30, 0.20, 0.40, 0.20, 0.40, 0.22, 0.30, 0.22] }
    ]
  },
  "confidence": 0.98,
  "provenance": { "extractor": "rules+model", "model_version": "pii-v4" }
}
```

The triple anchor is robust to tokenisation drift, coordinate-system shifts, and cross-page mentions. Use `page_regions` (not `token_ids`) as the final source for redaction geometry.

---

## `actions`

### `redactions`

```json
{
  "id": "r1",
  "entity_id": "e1",
  "page_id": "p1",
  "regions": [
    { "quad": [0.298, 0.198, 0.402, 0.198, 0.402, 0.222, 0.298, 0.222] }
  ],
  "mode": "burn_in",
  "label": "SSN",
  "confidence": 0.98,
  "status": "applied"
}
```

`regions` is always an array — a single entity can span multiple lines, regions, or pages.

Modes: `burn_in` · `pdf_redact` · `metadata_sanitize`

Status lifecycle: `proposed` → `approved` → `applied` → `verified`

!!! warning "PDF redaction"
    `burn_in` draws a mask over the page image but does **not** remove underlying text from a born-digital PDF. For born-digital PDFs, use `pdf_redact` mode, which applies native PDF redaction objects and removes the underlying content stream. Always sanitize metadata and attachments separately.

---

## `telemetry`

```json
{
  "trace_id": "<otel-trace-id>",
  "resource": {
    "workflow_version": "du-1.0.0",
    "tenant": "internal"
  },
  "page_metrics": [
    {
      "page_id": "p1",
      "render_ms": 22,
      "preprocess_ms": 9,
      "ocr_ms": 44,
      "block_count": 18,
      "line_count": 61,
      "token_count": 411,
      "mean_token_confidence": 0.94,
      "low_conf_token_ratio": 0.06,
      "skew_angle_deg": -0.82
    }
  ],
  "warnings": [
    {
      "code": "low_conf_cluster",
      "page_id": "p1",
      "token_ids": ["t77", "t78", "t79"]
    }
  ]
}
```

Telemetry is a first-class layer. Quality signals (OCR confidence, skew, blur, low-confidence ratio) are span attributes, not just logs. Warnings carry structured context so they are actionable.

---

## ID conventions

| Object | ID format | Example |
|---|---|---|
| Document | `doc:sha256:<hex8>` | `doc:sha256:a3f4b2c1` |
| Artifact | `a<n>` or `a<n>:p<n>` | `a1:p1` |
| Transform | `tr:<stage>:p<n>` | `tr:deskew:p1` |
| Page | `p<n>` | `p1` |
| Block | `b<n>` | `b1` |
| Line | `l<n>` | `l1` |
| Token | `t<n>` | `t1` |
| Text stream | `ts:doc` or `ts:p<n>` | `ts:doc` |
| Entity | `e<n>` | `e1` |
| Redaction | `r<n>` | `r1` |

All IDs are document-scoped and stable across pipeline re-runs for the same source artifact.

---

## Design influences

This schema is not a direct copy of any single standard. It deliberately synthesises:

- **PAGE-XML** — page geometry, alternative artifacts, reading order groups, multiple `TextEquiv` hypotheses
- **Azure Document Intelligence** — reading-order content string, spans, bounding regions as arrays
- **Google Document AI** — `textAnchor` + `pageAnchor` triple reference, bounding polygons
- **Amazon Textract** — Block objects with geometry, IDs, and typed relationship graphs
- **W3C Web Annotation / Text Position Selector** — `{start, end}` text-stream spans
- **PROV-O** — activity lineage (transforms as activities, artifacts as entities)
- **OpenTelemetry** — span-and-attribute telemetry model with semantic conventions
