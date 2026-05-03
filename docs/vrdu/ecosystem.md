# Python Ecosystem

An overview of the key Python libraries for visually rich document processing, organised by role in the pipeline.

---

## PDF Parsing

### pdfplumber

High-level PDF text and table extraction. Wraps pdfminer and exposes a clean API for extracting words, lines, rectangles, and tables with precise coordinates.

- Returns word-level bounding boxes out of the box
- Built-in table extraction using line/curve detection
- Good for structured, native PDFs with clear visual separators
- [GitHub](https://github.com/jsvine/pdfplumber)

```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    page = pdf.pages[0]
    words = page.extract_words()   # list of {text, x0, y0, x1, y1}
    tables = page.extract_tables() # list of list of list
```

### PyMuPDF (fitz)

Fast, comprehensive PDF and document processing library. Supports text extraction with coordinates, page rendering to images, metadata, annotations, and drawing.

- Significantly faster than pdfminer for large documents
- Can render pages to numpy arrays for downstream ML processing
- Handles XFA/AcroForm fields
- [GitHub](https://github.com/pymupdf/PyMuPDF)

```python
import fitz

doc = fitz.open("document.pdf")
page = doc[0]
blocks = page.get_text("dict")["blocks"]  # word-level with bbox
img = page.get_pixmap()                   # render to image
```

### pypdf

Lightweight pure-Python PDF reader. Good for text extraction, metadata, and page manipulation where precision layout data isn't needed.

- No binary dependencies
- Not suitable for coordinate-level extraction
- [GitHub](https://github.com/py-pdf/pypdf)

---

## OCR

### pytesseract

Python wrapper around Tesseract OCR. Returns bounding boxes alongside recognised text via `image_to_data`.

```python
import pytesseract
from PIL import Image

data = pytesseract.image_to_data(Image.open("scan.png"),
                                  output_type=pytesseract.Output.DICT)
# keys: text, left, top, width, height, conf
```

### PaddleOCR

Baidu's high-accuracy, multilingual OCR. Supports end-to-end detection + recognition with 80+ languages. Good choice when accuracy or non-Latin scripts are required.

```python
from paddleocr import PaddleOCR

ocr = PaddleOCR(lang="en")
result = ocr.ocr("scan.png")
# each item: [[bbox_points], (text, confidence)]
```

---

## Layout Analysis

### layoutparser

Unified API for document layout detection. Ships with pre-trained models (Faster R-CNN / Mask R-CNN on PubLayNet, PrimaLayout, TableBank) and supports custom fine-tuned models.

```python
import layoutparser as lp

model = lp.Detectron2LayoutModel(
    "lp://PubLayNet/mask_rcnn_X_101_32x8d_FPN_3x/config"
)
layout = model.detect(image)
text_blocks = layout.filter_by(lp.TextBlock, "Text")
```

### deepdoctection

Comprehensive document analysis framework covering detection, layout analysis, OCR, and table extraction in a unified pipeline. More batteries-included than layoutparser.

- [GitHub](https://github.com/deepdoctection/deepdoctection)

---

## End-to-End Document Processing

### docling

Modern document understanding library from IBM. Handles PDF, DOCX, PPTX, images with integrated layout analysis and structured output.

- Active development; strong table and figure handling
- Outputs clean Markdown or structured JSON
- [GitHub](https://github.com/DS4SD/docling)

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()
result = converter.convert("document.pdf")
print(result.document.export_to_markdown())
```

### unstructured

End-to-end document ingestion library designed for LLM and RAG pipelines. Handles a broad range of formats (PDF, DOCX, HTML, PPTX, images) with automatic chunking and element classification.

- Elements: `Title`, `NarrativeText`, `Table`, `ListItem`, `Image`
- Supports both local and API-based processing
- [GitHub](https://github.com/Unstructured-IO/unstructured)

```python
from unstructured.partition.pdf import partition_pdf

elements = partition_pdf("document.pdf")
for el in elements:
    print(type(el).__name__, el.text[:60])
```

---

## Ecosystem Summary

| Library | Role | Best for |
|---|---|---|
| pdfplumber | PDF parsing | Native PDFs with clear structure |
| PyMuPDF | PDF parsing + rendering | Speed, rendering pages to images |
| pypdf | PDF utilities | Metadata, simple text |
| pytesseract | OCR | Quick Tesseract integration |
| PaddleOCR | OCR | Accuracy, multilingual |
| layoutparser | Layout detection | Region detection with pretrained models |
| deepdoctection | Layout + extraction pipeline | Full pipeline without custom assembly |
| docling | End-to-end conversion | Markdown/structured output from PDFs |
| unstructured | End-to-end ingestion | RAG / LLM pipelines, mixed document types |

---

## Relationship to docunderstand

`docunderstand` is designed to integrate cleanly with these tools. The ingestion layer wraps `pdfplumber` and `PyMuPDF`. The OCR layer wraps `pytesseract` and `PaddleOCR` as optional backends. The layout layer optionally delegates to `layoutparser` or `docling`. The pipeline model means you can substitute any component with a library of your choice.
