import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Structured result of analyzing a payment receipt photo or text.
class ReceiptExtractionResult {
  const ReceiptExtractionResult({
    this.amount,
    this.referenceNumber,
    this.paymentMethod,
    this.rawText = '',
  });

  const ReceiptExtractionResult.empty()
      : amount = null,
        referenceNumber = null,
        paymentMethod = null,
        rawText = '';

  /// Detected payment amount (in PHP), e.g. 1500.0.
  final double? amount;

  /// Detected reference number or transaction ID, e.g. "0024 1234 5678".
  final String? referenceNumber;

  /// Inferred payment method: "GCash", "Maya", or "Bank transfer".
  final String? paymentMethod;

  /// Complete raw text extracted by OCR engine.
  final String rawText;

  /// Returns true if at least one meaningful field was successfully extracted.
  bool get hasMatches =>
      amount != null ||
      (referenceNumber != null && referenceNumber!.isNotEmpty) ||
      paymentMethod != null;

  @override
  String toString() =>
      'ReceiptExtractionResult(amount: $amount, ref: $referenceNumber, method: $paymentMethod)';
}

/// Service that performs on-device OCR on payment receipts (GCash, Maya, Bank slips)
/// and extracts reference numbers, payment amounts, and payment methods.
class ReceiptOcrService {
  const ReceiptOcrService();

  /// Scans an image file on disk using on-device ML Kit text recognition.
  ///
  /// On platforms where ML Kit native libraries are unsupported (e.g. Windows/macOS desktop or Web),
  /// this fails gracefully and returns [ReceiptExtractionResult.empty] without throwing errors.
  Future<ReceiptExtractionResult> scanReceiptFile(String filePath) async {
    if (filePath.isEmpty) {
      return const ReceiptExtractionResult.empty();
    }

    // ML Kit Text Recognition native plugins only support Android and iOS.
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (!isMobile) {
      debugPrint(
        'ReceiptOcrService: On-device ML Kit is active on Android/iOS. '
        'Skipping native processing on ${defaultTargetPlatform.name}.',
      );
      return const ReceiptExtractionResult.empty();
    }

    TextRecognizer? recognizer;
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);

      debugPrint(
          'ReceiptOcrService: Recognized text from receipt:\n${recognizedText.text}');
      final result = parseReceiptText(recognizedText.text);
      debugPrint('ReceiptOcrService: Extracted result -> $result');
      return result;
    } catch (e, st) {
      debugPrint('ReceiptOcrService error while scanning $filePath: $e\n$st');
      return const ReceiptExtractionResult.empty();
    } finally {
      await recognizer?.close();
    }
  }

  /// Parses raw text extracted from a receipt to find reference numbers, amounts,
  /// and payment methods.
  ReceiptExtractionResult parseReceiptText(String text) {
    if (text.trim().isEmpty) {
      return const ReceiptExtractionResult.empty();
    }

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);

    final paymentMethod = _detectPaymentMethod(normalized);
    final referenceNumber = _extractReferenceNumber(lines, normalized);
    final amount =
        _extractAmount(lines, normalized, referenceNumber: referenceNumber);

    return ReceiptExtractionResult(
      amount: amount,
      referenceNumber: referenceNumber,
      paymentMethod: paymentMethod,
      rawText: text,
    );
  }

  // ===========================================================================
  // Payment Method Detection
  // ===========================================================================

  String? _detectPaymentMethod(String text) {
    final lower = text.toLowerCase();

    // GCash indicators
    if (lower.contains('gcash') ||
        lower.contains('express send') ||
        lower.contains('send money to') ||
        lower.contains('sent to gcash') ||
        lower.contains('gcash ref')) {
      return 'GCash';
    }

    // Maya indicators
    if (lower.contains('maya') ||
        lower.contains('paymaya') ||
        lower.contains('maya philippines') ||
        lower.contains('send money via maya')) {
      return 'Maya';
    }

    // Bank transfer indicators
    final bankTerms = [
      'instapay',
      'pesonet',
      'bpi',
      'bdo',
      'unionbank',
      'metrobank',
      'rcbc',
      'security bank',
      'landbank',
      'chinabank',
      'bank transfer',
      'fund transfer',
      'transferred to bank',
    ];

    for (final term in bankTerms) {
      if (lower.contains(term)) {
        return 'Bank transfer';
      }
    }

    return null;
  }

  // ===========================================================================
  // Reference Number Extraction
  // ===========================================================================

  String? _extractReferenceNumber(List<String> lines, String fullText) {
    // 1. Primary labeled patterns: "Ref No. 0024 1234 5678", "Reference ID: 9482710384", etc.
    final labeledRegexes = [
      // Standard GCash / receipt format: "Ref. No. 0021 3456 7890" or "Ref No. 1002 9384 1029"
      RegExp(
        r'(?:ref(?:erence)?\.?\s*(?:no|num|number|id)?|trace\s*(?:no|number|id)?|confirmation\s*(?:no|number|id)?|instapay\s*ref(?:erence)?|txn\s*(?:no|id|ref)?)\s*[:.\-#]?\s*([A-Za-z0-9][A-Za-z0-9\s-]{5,30})',
        caseSensitive: false,
      ),
      // Standalone "Reference:" or "Trace:" label
      RegExp(
        r'\b(?:reference|trace|ref)\s*[:.\-]\s*([A-Za-z0-9][A-Za-z0-9\s-]{5,30})',
        caseSensitive: false,
      ),
    ];

    for (final regex in labeledRegexes) {
      for (final line in lines) {
        // If line has a decimal amount to the right (e.g. "Ref No. 100 293 841 1,500.00"),
        // strip the amount so the reference regex does not bleed into the amount!
        final lineWithoutAmount = line.replaceFirst(
          RegExp(
              r'\s+(?:php|php\.|₱|(?<![a-zA-Z])p\.?\s*)?[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}\b',
              caseSensitive: false),
          '',
        );

        final match = regex.firstMatch(lineWithoutAmount);
        if (match != null) {
          final candidate = _cleanReferenceCandidate(match.group(1));
          if (_isValidReference(candidate)) {
            return candidate;
          }
        }
      }
    }

    // 2. Multiline labeled pattern (where "Ref No." is on one line and the number is on the next line)
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].toLowerCase();
      if (line == 'ref no.' ||
          line == 'ref. no.' ||
          line == 'ref no' ||
          line == 'reference no' ||
          line == 'reference no.' ||
          line == 'reference id' ||
          line == 'reference number' ||
          line == 'transaction id') {
        final nextLine = lines[i + 1].trim();
        final nextLineWithoutAmount = nextLine.replaceFirst(
          RegExp(
              r'\s+(?:php|php\.|₱|(?<![a-zA-Z])p\.?\s*)?[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}\b',
              caseSensitive: false),
          '',
        );
        final candidate = _cleanReferenceCandidate(nextLineWithoutAmount);
        if (_isValidReference(candidate)) {
          return candidate;
        }
      }
    }

    // 3. Fallback: Search for characteristic GCash 13-digit pattern grouped in 4-4-5 or 4-4-4
    // e.g. "0024 1234 5678" or "1029 4829 1029"
    final gcashPattern = RegExp(r'\b(\d{4}\s\d{4}\s\d{4,5})\b');
    final gcashMatch = gcashPattern.firstMatch(fullText);
    if (gcashMatch != null) {
      final candidate = gcashMatch.group(1)!.trim();
      if (_isValidReference(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  String _cleanReferenceCandidate(String? raw) {
    if (raw == null) return '';
    var text = raw.trim();

    // Cut off if trailing words or dates bleed in
    final cutoffs = [
      ' date',
      ' time',
      ' amount',
      ' php',
      ' paid',
      ' sent',
      ' via',
      ' completed',
      ' successful',
    ];
    for (final cutoff in cutoffs) {
      final idx = text.toLowerCase().indexOf(cutoff);
      if (idx != -1) {
        text = text.substring(0, idx).trim();
      }
    }

    // Strip trailing decimal amount on the same line (e.g. "100 293 841 1,500.00" -> "100 293 841")
    final trailingAmount = RegExp(
      r'\s+(?:php|php\.|₱|[Pp]\.?\s*)?[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}$',
      caseSensitive: false,
    ).firstMatch(text);
    if (trailingAmount != null) {
      text = text.substring(0, trailingAmount.start).trim();
    }

    // Normalize multiple spaces into single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text;
  }

  bool _isValidReference(String candidate) {
    if (candidate.length < 6 || candidate.length > 32) return false;

    // Must contain at least some digits
    final digitCount = candidate.replaceAll(RegExp(r'\D'), '').length;
    if (digitCount < 5) return false;

    // Discard if it looks like a phone number (09xx xxx xxxx with exactly 11 digits)
    final cleanDigits = candidate.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length == 11 && cleanDigits.startsWith('09')) {
      return false;
    }

    // Discard if it looks like a date/time (e.g. "2026-09-11" or "09/11/2026")
    if (RegExp(r'^\d{4}[-/]\d{2}[-/]\d{2}$').hasMatch(candidate) ||
        RegExp(r'^\d{2}[-/]\d{2}[-/]\d{4}$').hasMatch(candidate)) {
      return false;
    }

    return true;
  }

  // ===========================================================================
  // Amount Extraction
  // ===========================================================================

  double? _extractAmount(
    List<String> lines,
    String fullText, {
    String? referenceNumber,
  }) {
    final candidates = <_AmountCandidate>[];
    final cleanRefDigits = referenceNumber?.replaceAll(RegExp(r'\D'), '');

    void addCandidate(
      String? textNumber,
      int baseScore,
      String source, {
      bool isFeeLine = false,
    }) {
      if (textNumber == null) return;
      final parsed = _parseNumeric(textNumber);
      if (parsed == null || !_isValidPaymentAmount(parsed)) return;

      // Disqualify if parsed number is just the leading digits of the reference number
      if (cleanRefDigits != null && cleanRefDigits.isNotEmpty) {
        final parsedDigits = parsed.toInt().toString();
        // Disqualify if matching start of ref number (e.g. "100" from "100293841029")
        if (cleanRefDigits.startsWith(parsedDigits) &&
            parsedDigits.length <= 4) {
          return;
        }
        // Disqualify if matching full or large portion of ref number
        if (cleanRefDigits == parsedDigits ||
            (parsedDigits.length >= 6 &&
                cleanRefDigits.contains(parsedDigits))) {
          return;
        }
      }

      // Heavily penalize fee lines so they never win over the principal payment
      final score = isFeeLine ? (baseScore - 150) : baseScore;
      candidates.add(_AmountCandidate(parsed, score, source));
    }

    // 1. Amount to the right of Reference Number on the same line (Score: 110 - HIGHEST PRIORITY)
    // Matches patterns like:
    // "Ref No. 1002 9384 1029    PHP 1,500.00"
    // "Ref No. 100 293 841        1,500.00"
    // "Ref: 100293841029         ₱1,500.00"
    final refWithAmountRegex = RegExp(
      r'(?:ref(?:erence)?\.?\s*(?:no|num|number|id)?|trace|confirmation)[^0-9]*[0-9\s-]{6,25}\s+(?:php|php\.|₱|(?<![a-zA-Z])p\.?\s*)?\s*([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2})\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = refWithAmountRegex.firstMatch(line);
      if (match != null) {
        addCandidate(match.group(1), 110, 'amount_right_of_ref: $line');
      }
    }

    // 2. Explicit labeled lines (e.g. "Total Amount Sent PHP 1,500.00", "Amount: ₱1,500.00", "Amount (PHP): 1500.00")
    final labeledAmountRegex = RegExp(
      r'(?:total\s+amount\s+sent|amount\s+sent|total\s+amount|payment\s+amount|transfer\s+amount|transferred\s+amount|net\s+amount|amount\s*\(php\)|amount\s*\(₱\)|amount|total|you\s+sent)\s*[:.\-]?\s*(?:php|php\.|₱|(?<![a-zA-Z])p\.?\s*)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final lower = line.toLowerCase();
      final isFee = lower.contains('fee') || lower.contains('charge');
      final isBalance = lower.contains('balance');
      if (isBalance) continue;

      final match = labeledAmountRegex.firstMatch(line);
      if (match != null) {
        addCandidate(match.group(1), 100, 'labeled_line: $line',
            isFeeLine: isFee);
      }
    }

    // 3. Multiline labeled pattern: line i contains "Amount" or "Total Amount Sent", line i+1 or i+2 contains the number
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].toLowerCase();
      final isAmountLabel = line.contains('amount') ||
          line.contains('total') ||
          (!line.contains('sent to') && line.contains('sent'));

      if (isAmountLabel && !line.contains('balance') && !line.contains('fee')) {
        for (var offset = 1;
            offset <= 2 && (i + offset) < lines.length;
            offset++) {
          final targetLine = lines[i + offset].trim();
          final isFee = targetLine.toLowerCase().contains('fee') ||
              targetLine.toLowerCase().contains('charge');
          if (targetLine.toLowerCase().contains('balance')) continue;

          final numberMatch = RegExp(
            r'(?:php|php\.|₱|(?<![a-zA-Z])p\.?\s*)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
            caseSensitive: false,
          ).firstMatch(targetLine);

          if (numberMatch != null && numberMatch.group(1) != null) {
            addCandidate(
              numberMatch.group(1),
              90 - (offset * 5),
              'multiline: $line -> $targetLine',
              isFeeLine: isFee,
            );
          }
        }
      }
    }

    // 4. Currency-prefixed amounts anywhere in text (e.g. "PHP 1,500.00", "₱1,500.00", "P1,500.00", "P 500.00")
    // NOTE: (?<![a-zA-Z]) ensures 'P' or 'PHP' is not the tail of a word like 'Ref' or 'Sep'
    final currencyRegex = RegExp(
      r'(?<![a-zA-Z])(?:php|php\.|₱|p\.?)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final lower = line.toLowerCase();
      final isFee = lower.contains('fee') || lower.contains('charge');
      if (lower.contains('balance')) continue;

      for (final match in currencyRegex.allMatches(line)) {
        addCandidate(match.group(1), 85, 'currency_prefix: $line',
            isFeeLine: isFee);
      }
    }

    // 5. Standalone decimal amounts (e.g. "1,500.00", "500.00", "1250.50")
    final decimalRegex = RegExp(
      r'\b([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2})\b',
    );

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('date') || lower.contains('balance')) {
        continue;
      }
      final isFee = lower.contains('fee') || lower.contains('charge');

      for (final match in decimalRegex.allMatches(line)) {
        addCandidate(match.group(1), 75, 'standalone_decimal: $line',
            isFeeLine: isFee);
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    // Sort candidates by score descending
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // If top candidates share the top score, choose by frequency, then higher amount
    final topScore = candidates.first.score;
    final topCandidates = candidates.where((c) => c.score == topScore).toList();
    if (topCandidates.length > 1) {
      final counts = <double, int>{};
      for (final c in topCandidates) {
        counts[c.amount] = (counts[c.amount] ?? 0) + 1;
      }
      topCandidates.sort((a, b) {
        final freqA = counts[a.amount] ?? 0;
        final freqB = counts[b.amount] ?? 0;
        if (freqA != freqB) return freqB.compareTo(freqA);
        return b.amount.compareTo(a.amount);
      });
      return topCandidates.first.amount;
    }

    return candidates.first.amount;
  }

  double? _parseNumeric(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }

  bool _isValidPaymentAmount(double amount) {
    // Dormitory bills range between 10 PHP and 1,000,000 PHP.
    return amount >= 10.0 && amount <= 1000000.0;
  }
}

class _AmountCandidate {
  const _AmountCandidate(this.amount, this.score, this.source);

  final double amount;
  final int score;
  final String source;

  @override
  String toString() =>
      '_AmountCandidate($amount, score: $score, from: $source)';
}
