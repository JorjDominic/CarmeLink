"""Read real generated local fixture PDFs; never reads live financial data."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path('build/phase4_pdf_tools').resolve()))
from pypdf import PdfReader
root = Path('build/financial_receipt_validation')
for source in ['verification', 'recovery', 'legacy']:
    for environment in ['manual', 'test', 'live']:
        text = '\n'.join(page.extract_text() for page in PdfReader(root / f'{environment}_{source}.pdf').pages)
        flat = ''.join(text.split())
        for expected in ['PAY-TRANSACTION-FIXTURE', 'PAYMENT-REF', 'Original Tenant', 'Original October rent', 'Bill ID: bill-fixture', 'PHP 200.00', 'PHP 800.00', '2026-10-16']:
            assert ''.join(expected.split()) in flat, (environment, source, expected)
        assert ('TEST TRANSACTION' in text) == (environment == 'test')
        if source == 'verification': assert 'Balanceafterthispayment' in flat
        if source == 'recovery': assert 'Balancewhenreceiptwasrecovered' in flat and 'receiptrecovery' in flat
        if source == 'legacy': assert 'Balancerecordedonreceipt' in flat
text = '\n'.join(page.extract_text() for page in PdfReader(root / 'financial.pdf').pages)
assert 'VERIFIED COLLECTIONS\nPHP 250.00' in text, text
assert 'TESTcreditsexcluded' in ''.join(text.split())
executive = '\n'.join(page.extract_text() for page in PdfReader(root / 'executive.pdf').pages)
assert 'PHP 250.00' in executive
print('PASS 9 receipt PDFs: transaction references, immutable details, dates, partial balances, test labels and recovery labels')
print('PASS actual financial and executive PDF collections exclude test credits and retain manual cash')
