# Advanced PDF Processing

This document covers advanced features, JavaScript libraries, and specialized operations not covered in the main skill instructions.

## pypdfium2 (Fast Rendering)

pypdfium2 is a Python binding for PDFium (Chromium's PDF library). Excellent for fast rendering and image generation.

```python
import pypdfium2 as pdfium

def render_page_to_image(pdf_path: str, page_num: int = 0, scale: float = 2.0):
    """Render a PDF page to a PIL Image at given scale."""
    pdf = pdfium.PdfDocument(pdf_path)
    page = pdf[page_num]
    bitmap = page.render(scale=scale)
    image = bitmap.to_pil()
    return image

def pdf_to_images(pdf_path: str, output_dir: str, scale: float = 2.0):
    """Convert all PDF pages to images."""
    import os
    os.makedirs(output_dir, exist_ok=True)
    
    pdf = pdfium.PdfDocument(pdf_path)
    for i in range(len(pdf)):
        page = pdf[i]
        bitmap = page.render(scale=scale)
        image = bitmap.to_pil()
        image.save(os.path.join(output_dir, f"page_{i + 1}.png"))
```

## JavaScript Libraries

### pdf-lib (Node.js / Browser)

Modern, pure-JS library for creating and modifying PDFs:

```javascript
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';
import fs from 'fs';

async function createPdf(outputPath) {
  const pdfDoc = await PDFDocument.create();
  const page = pdfDoc.addPage([612, 792]); // Letter size
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  
  page.drawText('Hello, PDF!', {
    x: 50,
    y: 700,
    size: 30,
    font,
    color: rgb(0, 0.2, 0.6),
  });

  const pdfBytes = await pdfDoc.save();
  fs.writeFileSync(outputPath, pdfBytes);
}

async function mergePdfs(pdfPaths, outputPath) {
  const mergedPdf = await PDFDocument.create();
  
  for (const path of pdfPaths) {
    const pdfBytes = fs.readFileSync(path);
    const pdf = await PDFDocument.load(pdfBytes);
    const pages = await mergedPdf.copyPages(pdf, pdf.getPageIndices());
    pages.forEach(page => mergedPdf.addPage(page));
  }

  const mergedBytes = await mergedPdf.save();
  fs.writeFileSync(outputPath, mergedBytes);
}

async function fillForm(inputPath, outputPath, fields) {
  const pdfBytes = fs.readFileSync(inputPath);
  const pdfDoc = await PDFDocument.load(pdfBytes);
  const form = pdfDoc.getForm();

  for (const [name, value] of Object.entries(fields)) {
    const field = form.getTextField(name);
    if (field) field.setText(value);
  }

  const filledBytes = await pdfDoc.save();
  fs.writeFileSync(outputPath, filledBytes);
}
```

### jsPDF (Browser-focused)

```javascript
import { jsPDF } from 'jspdf';
import 'jspdf-autotable';

function createReport(title, tableData, outputPath) {
  const doc = new jsPDF();
  
  // Title
  doc.setFontSize(20);
  doc.text(title, 105, 20, { align: 'center' });
  
  // Body text
  doc.setFontSize(12);
  doc.text('Generated report with auto-table support.', 14, 40);
  
  // Table
  doc.autoTable({
    startY: 50,
    head: [tableData.headers],
    body: tableData.rows,
    theme: 'striped',
    headStyles: { fillColor: [66, 139, 202] }
  });

  doc.save(outputPath);
}
```

## Advanced ReportLab Patterns

### Multi-page documents with headers/footers

```python
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Frame, PageTemplate
from reportlab.lib.styles import getSampleStyleSheet

class NumberedCanvas:
    """Add page numbers to every page."""
    def __init__(self, canvas, doc):
        self.canvas = canvas
        self.doc = doc
        canvas.saveState()
        canvas.setFont("Helvetica", 9)
        canvas.drawRightString(
            letter[0] - 72, 36,
            f"Page {doc.page}"
        )
        canvas.restoreState()

def create_document_with_headers(output_path, title, content):
    doc = SimpleDocTemplate(output_path, pagesize=letter)
    
    def header_footer(canvas, doc):
        canvas.saveState()
        # Header
        canvas.setFont("Helvetica-Bold", 10)
        canvas.drawString(72, letter[1] - 50, title)
        canvas.line(72, letter[1] - 55, letter[0] - 72, letter[1] - 55)
        # Footer
        canvas.setFont("Helvetica", 9)
        canvas.drawRightString(letter[0] - 72, 36, f"Page {doc.page}")
        canvas.restoreState()

    doc.build(content, onFirstPage=header_footer, onLaterPages=header_footer)
```

### Charts and Graphics

```python
from reportlab.graphics.shapes import Drawing
from reportlab.graphics.charts.barcharts import VerticalBarChart
from reportlab.lib import colors

def create_bar_chart(data, categories, title=""):
    """Create a bar chart drawing."""
    drawing = Drawing(400, 200)
    chart = VerticalBarChart()
    chart.x = 50
    chart.y = 50
    chart.width = 300
    chart.height = 125
    chart.data = data
    chart.categoryAxis.categoryNames = categories
    chart.valueAxis.valueMin = 0
    chart.bars[0].fillColor = colors.steelblue
    drawing.add(chart)
    return drawing
```

## Batch Processing Patterns

```python
import os
from concurrent.futures import ProcessPoolExecutor
from pypdf import PdfReader

def batch_extract_text(pdf_dir: str, output_dir: str, max_workers: int = 4):
    """Extract text from all PDFs in a directory."""
    os.makedirs(output_dir, exist_ok=True)
    pdf_files = [f for f in os.listdir(pdf_dir) if f.endswith('.pdf')]

    def process_one(filename):
        input_path = os.path.join(pdf_dir, filename)
        output_path = os.path.join(output_dir, filename.replace('.pdf', '.txt'))
        try:
            reader = PdfReader(input_path)
            text = "\n\n".join(page.extract_text() or "" for page in reader.pages)
            with open(output_path, "w") as f:
                f.write(text)
            return filename, "success"
        except Exception as e:
            return filename, f"error: {e}"

    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        results = list(executor.map(process_one, pdf_files))

    return results
```

## PDF/A Compliance (Archival)

```bash
# Convert to PDF/A using Ghostscript
gs -dPDFA -dBATCH -dNOPAUSE -sColorConversionStrategy=UseDeviceIndependentColor \
   -sDEVICE=pdfwrite -dPDFACompatibilityPolicy=2 \
   -sOutputFile=output_pdfa.pdf input.pdf

# Validate PDF/A with verapdf
verapdf --flavour 2b input.pdf
```

## Redaction

```python
import pdfplumber
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from pypdf import PdfReader, PdfWriter
import io
import re

def redact_text(input_path: str, output_path: str, patterns: list):
    """Redact text matching regex patterns with black boxes.
    
    Args:
        patterns: List of regex patterns to redact
    """
    reader = PdfReader(input_path)
    writer = PdfWriter()

    with pdfplumber.open(input_path) as pdf:
        for page_num, page in enumerate(pdf.pages):
            # Find text positions to redact
            words = page.extract_words()
            redact_boxes = []
            
            for word in words:
                for pattern in patterns:
                    if re.search(pattern, word['text']):
                        redact_boxes.append((
                            word['x0'], word['top'],
                            word['x1'], word['bottom']
                        ))

            # Create redaction overlay
            packet = io.BytesIO()
            page_width = page.width
            page_height = page.height
            c = canvas.Canvas(packet, pagesize=(page_width, page_height))
            c.setFillColorRGB(0, 0, 0)
            
            for (x0, top, x1, bottom) in redact_boxes:
                # pdfplumber coords are top-down, reportlab is bottom-up
                y0 = page_height - bottom
                y1 = page_height - top
                c.rect(x0, y0, x1 - x0, y1 - y0, fill=1, stroke=0)
            
            c.save()
            packet.seek(0)

            # Merge redaction overlay with original page
            if redact_boxes:
                overlay_reader = PdfReader(packet)
                original_page = reader.pages[page_num]
                original_page.merge_page(overlay_reader.pages[0])
                writer.add_page(original_page)
            else:
                writer.add_page(reader.pages[page_num])

    writer.write(output_path)
    writer.close()
```

## Metadata Operations

```python
from pypdf import PdfReader, PdfWriter
from datetime import datetime

def update_metadata(input_path: str, output_path: str, metadata: dict):
    """Update PDF metadata (title, author, subject, etc.)."""
    reader = PdfReader(input_path)
    writer = PdfWriter()
    
    for page in reader.pages:
        writer.add_page(page)
    
    writer.add_metadata({
        "/Title": metadata.get("title", ""),
        "/Author": metadata.get("author", ""),
        "/Subject": metadata.get("subject", ""),
        "/Creator": metadata.get("creator", "Python PDF Skill"),
        "/Producer": "pypdf",
        "/CreationDate": datetime.now().strftime("D:%Y%m%d%H%M%S"),
    })
    
    writer.write(output_path)
    writer.close()

def read_metadata(pdf_path: str) -> dict:
    """Read PDF metadata."""
    reader = PdfReader(pdf_path)
    meta = reader.metadata
    return {
        "title": meta.title,
        "author": meta.author,
        "subject": meta.subject,
        "creator": meta.creator,
        "producer": meta.producer,
        "pages": len(reader.pages),
    }
```
