"""Inspect the actual exported fixture PDF; never uses live financial data."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path("build/phase4_pdf_tools").resolve()))
from pypdf import PdfReader

text = "\n".join(page.extract_text() for page in PdfReader("build/phase4_reports/financial.pdf").pages)
names = ["OCT2026", "NOV2026", "YEAR2027", "UNDATED"]
positions = [text.index(name) for name in names]
assert positions == sorted(positions), "PDF row order is not chronological"
assert "Oct 12, 2026" in text and "Nov 12, 2026" in text and "Oct 12, 2027" in text
assert "UNDATED OTHER Not specified" in text, "Missing due date was fabricated"
assert "AIRCON REPAIR" in text, "Specified category missing from PDF"
assert "VERIFIED COLLECTIONS\nPHP 500.00" in text
assert "OUTSTANDING DUES\nPHP 2600.00" in text
assert "PHP 3000.00 PHP 500.00 PHP 2500.00 Partially paid" in text
executive = "\n".join(page.extract_text() for page in PdfReader("build/phase4_reports/executive.pdf").pages)
assert "PHP 500.00" in executive and "PHP 2600.00" in executive
print("PASS actual PDF chronology, undated rows, specified category, partial cash/balance and unchanged executive totals")
