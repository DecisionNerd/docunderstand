# Models and Methods

An overview of the key neural approaches to visually rich document understanding.

---

## The LayoutLM Family

Microsoft's LayoutLM series established multimodal pre-training as the dominant paradigm for VRDU. Each version adds a new information modality to a transformer backbone.

### LayoutLM

**LayoutLM: Pre-training of Text and Layout for Document Image Understanding** (2020)

The first model to explicitly encode spatial information alongside text. Input: OCR tokens + their 2D bounding box coordinates, embedded and summed with token embeddings before feeding into BERT.

- Pre-trained on IIT-CDIP (~11 million document images)
- Achieves large gains over text-only BERT on FUNSD and RVL-CDIP
- Key insight: x/y coordinates carry nearly as much signal as word order for form understanding

### LayoutLMv2

**LayoutLMv2: Multi-modal Pre-training for Visually-Rich Document Understanding** (2021)

Extends LayoutLM with visual features extracted from document images using ResNet. A spatial-aware self-attention mechanism biases attention scores using relative position.

- Text + layout + image, jointly pre-trained
- New pre-training tasks: text-image alignment, text-image matching
- Significant improvement on DocVQA, CORD, and FUNSD

### LayoutLMv3

**LayoutLMv3: Pre-training for Document AI with Unified Text and Image Masking** (2022)

Replaces the CNN image encoder with a patch-based vision transformer (ViT), aligning with advances in vision-language models. Introduces masked image modelling alongside masked language modelling for joint pre-training.

- Achieves state-of-the-art on FUNSD, CORD, DocVQA at time of publication
- Simpler architecture than v2 while being more effective
- [Paper](https://arxiv.org/abs/2204.08387)

---

## End-to-End Models

### Donut

**Document Understanding Transformer** (CLOVA AI, 2022)

Donut sidesteps OCR entirely. An image encoder (Swin Transformer) encodes the document image; a text decoder (BART-style) autoregressively produces structured output (JSON, key-value pairs, QA answers) directly.

- No explicit OCR step — text is "read" implicitly by the model
- Trained with massive synthetic document augmentation
- Strong zero-shot and few-shot transfer
- Particularly effective for constrained output schemas (receipts, forms)
- [Paper](https://arxiv.org/abs/2111.15664)

### Nougat

**Neural Optical Understanding for Academic Documents** (Meta, 2023)

Donut-style architecture specialised for scientific papers. Converts academic PDFs to structured Markdown, preserving equations (LaTeX), tables, and section hierarchy.

- Handles mathematical notation that defeats general OCR
- Trained on large corpus of arXiv papers paired with LaTeX source
- [Paper](https://arxiv.org/abs/2308.13418)

---

## OCR Foundations

### TrOCR

**Transformer-based Optical Character Recognition** (Microsoft, 2021)

Encoder-decoder transformer for text recognition. Image encoder (ViT or BEiT) + text decoder (RoBERTa-style), trained on large synthetic and real OCR datasets.

- Removes recurrence from the OCR pipeline entirely
- Strong results on handwritten and printed text across multiple languages
- [Paper](https://arxiv.org/abs/2109.10282)

### Tesseract

The industry-standard open-source OCR engine (Google). LSTM-based character recognition, supports 100+ languages. Version 4+ substantially improved accuracy over earlier versions. Widely used as the default OCR backend in document processing pipelines.

### PaddleOCR

Baidu's open-source OCR toolkit. Supports 80+ languages with highly optimised detection + recognition pipelines. Popular for production deployments due to efficiency and accuracy.

---

## Layout Analysis Models

### DiT

**Document Image Transformer** (Microsoft, 2022)

Vision transformer pre-trained on IIT-CDIP using masked image modelling (BEiT-style). Fine-tuned for document layout detection and classification.

- Treats document understanding as a vision-only problem
- Strong performance on PubLayNet and RVL-CDIP
- [Paper](https://arxiv.org/abs/2203.02378)

### LayoutParser

Not a single model, but a unified Python framework for document layout analysis. Provides pre-trained models (Faster R-CNN, Mask R-CNN) trained on PubLayNet and DocLayNet, with a consistent API for region detection.

---

## Multimodal Foundation Models

### Florence (Microsoft)

Large vision-language foundation model showing strong zero-shot transfer to document understanding tasks via CLIP-style alignment.

### GPT-4V / Claude (Multimodal LLMs)

Modern large multimodal models can perform ad-hoc document extraction directly from images. Useful for prototyping and low-volume extraction but typically slower and more expensive than fine-tuned specialist models for production scale.

---

## Model Selection Guide

| Use case | Recommended approach |
|---|---|
| Native PDF field extraction | Rule-based / heuristic (no ML needed) |
| Scanned form extraction (fixed schema) | Donut fine-tuned on schema |
| Scanned form extraction (ad-hoc queries) | LayoutLMv3 |
| Receipt / invoice parsing | CORD-fine-tuned Donut or LayoutLMv3 |
| Scientific paper extraction | Nougat |
| Layout detection | LayoutParser + DiT |
| Document classification | LayoutLMv3 or DiT |
| Document QA | LayoutLMv3 or GPT-4V (prototyping) |
