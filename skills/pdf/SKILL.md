---
name: pdf
description: "Comprehensive PDF manipulation toolkit for reading, creating, merging, splitting, and processing PDF documents. Use when tasks involve reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs to make them searchable. If the user mentions a .pdf file or asks to produce one, use this skill."
---

# PDF Processing Skill

This guide covers essential PDF processing operations using Python libraries and command-line tools. For advanced features, JavaScript libraries, and detailed examples, see `references/advanced.md`. If you need to fill out a PDF form, see the Forms section below.

## Core Libraries

### Library Selection Guide

| Task | Primary Library | Alternative |
|------|----------------|-------------|
| Read/extract text | `pdfplumber` | `pypdf` |
| Extract tables | `pdfplumber` | `camelot-py` |
| Create new PDFs | `reportlab` | `fpdf2` |
| Merge/split | `pypdf` | `qpdf` (CLI) |
| Fill forms | `pypdf` | `pdftk` (CLI) |
| Rotate/crop | `pypdf` | — |
| Watermarks | `pypdf` + `reportlab` | — |
| Encrypt/decrypt | `pypdf` | `qpdf` (CLI) |
| OCR (scanned) | `pytesseract` + `pdf2image` | `ocrmypdf` (CLI) |
| Render to image | `pypdfium2` | `pdf2image` (Poppler) |

### Installation

```bash
# Core libraries
pip install pypdf pdfplumber reportlab

# OCR support
pip install pytesseract pdf2image Pillow
# Also requires: apt-get install tesseract-ocr poppler-utils

# Advanced rendering
pip install pypdfium2

# Alternative creation library
pip install fpdf2
```

## Reading & Extracting Text

### Extract all text from a PDF

```python
import pdfplumber

def extract_text(pdf_path: str) -> str:
    """Extract all text from a PDF file."""
    text_parts = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text_parts.append(page_text)
    return "\n\n".join(text_parts)
```

### Extract tables from a PDF

```python
import pdfplumber
import csv

def extract_tables(pdf_path: str, output_csv: str = None) -> list:
    """Extract tables from PDF pages."""
    all_tables = []
    with pdfplumber.open(pdf_path) as pdf:
        for i, page in enumerate(pdf.pages):
            tables = page.extract_tables()
            for table in tables:
                all_tables.append({
                    "page": i + 1,
                    "data": table
                })

    if output_csv and all_tables:
        with open(output_csv, "w", newline="") as f:
            writer = csv.writer(f)
            for table in all_tables:
                writer.writerows(table["data"])
                writer.writerow([])  # separator between tables

    return all_tables
```

### Extract with pypdf (lighter weight)

```python
from pypdf import PdfReader

def extract_text_pypdf(pdf_path: str) -> str:
    """Extract text using pypdf (fewer dependencies)."""
    reader = PdfReader(pdf_path)
    text_parts = []
    for page in reader.pages:
        text_parts.append(page.extract_text())
    return "\n\n".join(text_parts)
```

## Creating New PDFs

### Using ReportLab

```python
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT

def create_report(output_path: str, title: str, content: list):
    """Create a professional PDF report.
    
    Args:
        output_path: Path for output PDF
        title: Report title
        content: List of dicts with 'type' and 'data' keys
                 Types: 'heading', 'paragraph', 'table', 'spacer', 'page_break'
    """
    doc = SimpleDocTemplate(
        output_path,
        pagesize=letter,
        rightMargin=72,
        leftMargin=72,
        topMargin=72,
        bottomMargin=72
    )

    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name='CustomTitle',
        parent=styles['Title'],
        fontSize=24,
        spaceAfter=30,
        alignment=TA_CENTER
    ))

    story = []
    story.append(Paragraph(title, styles['CustomTitle']))
    story.append(Spacer(1, 12))

    for item in content:
        if item['type'] == 'heading':
            story.append(Paragraph(item['data'], styles['Heading1']))
            story.append(Spacer(1, 6))
        elif item['type'] == 'paragraph':
            story.append(Paragraph(item['data'], styles['Normal']))
            story.append(Spacer(1, 12))
        elif item['type'] == 'table':
            table = Table(item['data'])
            table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 12),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ]))
            story.append(table)
            story.append(Spacer(1, 12))
        elif item['type'] == 'spacer':
            story.append(Spacer(1, item.get('height', 24)))
        elif item['type'] == 'page_break':
            story.append(PageBreak())

    doc.build(story)
```

### Using fpdf2 (simpler API)

```python
from fpdf import FPDF

def create_simple_pdf(output_path: str, title: str, body: str):
    """Create a simple PDF with fpdf2."""
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, title, new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.ln(10)
    pdf.set_font("Helvetica", "", 12)
    pdf.multi_cell(0, 7, body)
    pdf.output(output_path)
```

## Merging & Splitting

### Merge multiple PDFs

```python
from pypdf import PdfWriter

def merge_pdfs(input_paths: list, output_path: str):
    """Merge multiple PDF files into one."""
    writer = PdfWriter()
    for path in input_paths:
        writer.append(path)
    writer.write(output_path)
    writer.close()
```

### Split a PDF

```python
from pypdf import PdfReader, PdfWriter

def split_pdf(input_path: str, output_dir: str, pages_per_split: int = 1):
    """Split a PDF into smaller PDFs."""
    import os
    os.makedirs(output_dir, exist_ok=True)
    
    reader = PdfReader(input_path)
    total_pages = len(reader.pages)

    for start in range(0, total_pages, pages_per_split):
        writer = PdfWriter()
        end = min(start + pages_per_split, total_pages)
        for page_num in range(start, end):
            writer.add_page(reader.pages[page_num])
        
        output_path = os.path.join(output_dir, f"split_{start + 1}-{end}.pdf")
        writer.write(output_path)
        writer.close()

def extract_pages(input_path: str, output_path: str, page_numbers: list):
    """Extract specific pages from a PDF."""
    reader = PdfReader(input_path)
    writer = PdfWriter()
    for page_num in page_numbers:
        writer.add_page(reader.pages[page_num - 1])  # 1-indexed input
    writer.write(output_path)
    writer.close()
```

## Rotating & Transforming

```python
from pypdf import PdfReader, PdfWriter

def rotate_pages(input_path: str, output_path: str, rotation: int, pages: list = None):
    """Rotate pages in a PDF (90, 180, or 270 degrees).
    
    Args:
        pages: List of 1-indexed page numbers. None = all pages.
    """
    reader = PdfReader(input_path)
    writer = PdfWriter()

    for i, page in enumerate(reader.pages):
        if pages is None or (i + 1) in pages:
            page.rotate(rotation)
        writer.add_page(page)

    writer.write(output_path)
    writer.close()
```

## Watermarks

```python
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from reportlab.lib.colors import Color
import io

def add_watermark(input_path: str, output_path: str, watermark_text: str):
    """Add a diagonal text watermark to every page."""
    # Create watermark PDF in memory
    packet = io.BytesIO()
    c = canvas.Canvas(packet, pagesize=letter)
    c.setFont("Helvetica", 60)
    c.setFillColor(Color(0.5, 0.5, 0.5, alpha=0.3))
    c.saveState()
    c.translate(letter[0] / 2, letter[1] / 2)
    c.rotate(45)
    c.drawCentredString(0, 0, watermark_text)
    c.restoreState()
    c.save()
    packet.seek(0)

    # Apply watermark
    watermark_reader = PdfReader(packet)
    watermark_page = watermark_reader.pages[0]

    reader = PdfReader(input_path)
    writer = PdfWriter()

    for page in reader.pages:
        page.merge_page(watermark_page)
        writer.add_page(page)

    writer.write(output_path)
    writer.close()
```

## Encryption & Security

```python
from pypdf import PdfReader, PdfWriter

def encrypt_pdf(input_path: str, output_path: str, user_password: str, owner_password: str = None):
    """Encrypt a PDF with passwords."""
    reader = PdfReader(input_path)
    writer = PdfWriter()
    
    for page in reader.pages:
        writer.add_page(page)
    
    writer.encrypt(
        user_password=user_password,
        owner_password=owner_password or user_password,
        permissions_flag=0b0100  # Allow printing only
    )
    writer.write(output_path)
    writer.close()

def decrypt_pdf(input_path: str, output_path: str, password: str):
    """Decrypt a password-protected PDF."""
    reader = PdfReader(input_path)
    if reader.is_encrypted:
        reader.decrypt(password)
    
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    writer.write(output_path)
    writer.close()
```

## OCR (Scanned Documents)

```python
import pytesseract
from pdf2image import convert_from_path

def ocr_pdf(pdf_path: str, output_path: str = None, language: str = "eng") -> str:
    """Perform OCR on a scanned PDF to extract text.
    
    Requires: tesseract-ocr, poppler-utils
    """
    images = convert_from_path(pdf_path)
    text_parts = []

    for i, image in enumerate(images):
        text = pytesseract.image_to_string(image, lang=language)
        text_parts.append(f"--- Page {i + 1} ---\n{text}")

    full_text = "\n\n".join(text_parts)

    if output_path:
        with open(output_path, "w") as f:
            f.write(full_text)

    return full_text
```

### Using ocrmypdf (CLI — best quality)

```bash
# Basic OCR (creates searchable PDF)
ocrmypdf input.pdf output.pdf

# Force OCR even on pages that already have text
ocrmypdf --force-ocr input.pdf output.pdf

# Specific language
ocrmypdf -l fra input.pdf output.pdf

# Optimize file size
ocrmypdf --optimize 3 input.pdf output.pdf
```

## Extracting Images

```python
from pypdf import PdfReader
from PIL import Image
import io
import os

def extract_images(pdf_path: str, output_dir: str) -> list:
    """Extract all images from a PDF."""
    os.makedirs(output_dir, exist_ok=True)
    reader = PdfReader(pdf_path)
    image_paths = []

    for page_num, page in enumerate(reader.pages):
        for img_num, image in enumerate(page.images):
            img_path = os.path.join(output_dir, f"page{page_num + 1}_img{img_num + 1}_{image.name}")
            with open(img_path, "wb") as f:
                f.write(image.data)
            image_paths.append(img_path)

    return image_paths
```

## Forms

### Reading form fields

```python
from pypdf import PdfReader

def get_form_fields(pdf_path: str) -> dict:
    """Get all form fields and their current values."""
    reader = PdfReader(pdf_path)
    fields = reader.get_fields()
    return {name: field.get("/V", "") for name, field in (fields or {}).items()}
```

### Filling form fields

```python
from pypdf import PdfReader, PdfWriter

def fill_form(input_path: str, output_path: str, field_values: dict):
    """Fill a PDF form with provided values.
    
    Args:
        field_values: Dict mapping field names to values.
    """
    reader = PdfReader(input_path)
    writer = PdfWriter()
    writer.append(reader)
    writer.update_page_form_field_values(writer.pages[0], field_values)
    writer.write(output_path)
    writer.close()
```

## Command-Line Tools

### qpdf (fast, reliable)

```bash
# Merge PDFs
qpdf --empty --pages file1.pdf file2.pdf file3.pdf -- merged.pdf

# Split: extract pages 1-5
qpdf input.pdf --pages . 1-5 -- output.pdf

# Decrypt
qpdf --password=secret --decrypt encrypted.pdf decrypted.pdf

# Linearize (optimize for web viewing)
qpdf --linearize input.pdf optimized.pdf
```

### pdftk

```bash
# Merge
pdftk file1.pdf file2.pdf cat output merged.pdf

# Split all pages
pdftk input.pdf burst output page_%03d.pdf

# Rotate page 1 by 90 degrees
pdftk input.pdf cat 1east 2-end output rotated.pdf

# Fill form from FDF/XFDF
pdftk form.pdf fill_form data.fdf output filled.pdf flatten
```

## Best Practices

1. **Always close writers** — Use `writer.close()` or context managers
2. **Handle encrypted PDFs gracefully** — Check `reader.is_encrypted` before processing
3. **Validate output** — After creating a PDF, render a page to verify it looks correct
4. **Memory management** — For large PDFs, process page-by-page instead of loading all at once
5. **Error handling** — Wrap operations in try/except for malformed PDFs
6. **Use the right tool** — `pdfplumber` for reading, `reportlab` for creating, `pypdf` for manipulating
7. **Visual verification** — When layout matters, render pages to images and inspect before finalizing

## References

For advanced features, JavaScript libraries (pdf-lib, jsPDF), and more detailed examples, see `references/advanced.md`.
