import '../core/utils/financial_snapshot.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../controllers/owner_controller.dart';
import '../core/utils/conduct_case_policy.dart';
import 'conduct_case_service.dart';
import 'staff_maintenance_service.dart';

/// Professional PDF and Report generation service for Carmelita's Dormitory.
/// Supports both mobile (Android/iOS) and web with print, export, and sharing.
class DormitoryReportService {
  const DormitoryReportService();

  static const PdfColor primaryColor =
      PdfColor.fromInt(0xFF6B1D2F); // Carmelita Deep Wine
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFFC5A059); // Gold
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF2D3142);
  static const PdfColor lightBgColor = PdfColor.fromInt(0xFFF9F7F5);
  static const PdfColor tableBorderColor = PdfColor.fromInt(0xFFE2D9D2);

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatCurrency(double amount) => 'PHP ${amount.toStringAsFixed(2)}';

  String _formatDate(DateTime date) {
    final month = _monthNames[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    return '$month $day, ${date.year}';
  }

  String _formatDateTime(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$m-$day $h:$min';
  }

  String _truncate(String value, int maxLength) {
    final clean = value.trim();
    if (clean.length <= maxLength) return clean;
    return '${clean.substring(0, maxLength - 3)}...';
  }

  pw.Widget _buildReportHeader(String reportTitle, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: secondaryColor, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "CARMELITA'S DORMITORY",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Student & Professional Residential Management',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
              if (subtitle.isNotEmpty)
                pw.Text(
                  subtitle,
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Official Administrative Report',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: ${_formatDateTime(DateTime.now())}',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'Confidential & Internal Use Only',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.red700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReportFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: tableBorderColor, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "Carmelita's Dormitory System • Generated via CarmeLink Admin",
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryCard(String title, String value,
      {PdfColor color = primaryColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: lightBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: tableBorderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignOff() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 24),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 140, height: 1, color: PdfColors.grey500),
              pw.SizedBox(height: 4),
              pw.Text('Prepared / Verified By: Dormitory Caretaker',
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.grey800)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(width: 140, height: 1, color: PdfColors.grey500),
              pw.SizedBox(height: 4),
              pw.Text('Approved By: Carmelita Dormitory Management',
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.grey800)),
            ],
          ),
        ],
      ),
    );
  }

  // 1. FINANCIAL REPORT
  Future<Uint8List> generateFinancialReportPdf() async {
    final pdf = pw.Document();
    final controller = OwnerController.instance;
    final payments = controller.payments;

    final financial = FinancialSnapshot(payments);
    final totalPaid = financial.collected;
    final totalPending = financial.pending;
    final totalDue = financial.outstanding;
    final rentPaid = financial.rentCollected;
    final utilityPaid = financial.utilityCollected;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildReportHeader(
          'Financial & Rent Collection Statement',
          'Period: Current Operational Ledger • Verified Collections & Outstanding Balances',
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          // KPI Metric Row
          pw.Row(
            children: [
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Verified Collections', _formatCurrency(totalPaid),
                      color: PdfColors.green800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Pending Verification', _formatCurrency(totalPending),
                      color: PdfColors.amber800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Outstanding Dues', _formatCurrency(totalDue),
                      color: PdfColors.red800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Rent Collections', _formatCurrency(rentPaid),
                      color: primaryColor)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Utility Collections', _formatCurrency(utilityPaid),
                      color: secondaryColor)),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('ITEMIZED BILLING SUMMARY',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Invoice / Ref',
              'Resident Name',
              'Category',
              'Due Date',
              'Method',
              'Bill Amount',
              'Verified Cash',
              'Balance',
              'Status'
            ],
            data: payments.isEmpty
                ? [
                    [
                      'No billing charges recorded in the current ledger',
                      '',
                      '',
                      '',
                      '',
                      '',
                      '',
                      '',
                      ''
                    ]
                  ]
                : payments
                    .map((p) => [
                          p.reference ??
                              p.id.substring(
                                  0, p.id.length > 8 ? 8 : p.id.length),
                          p.tenantName ?? 'Resident',
                          p.category.toUpperCase(),
                          _formatDate(p.dueDate),
                          p.paymentMethod ?? 'Not recorded',
                          _formatCurrency(p.amount),
                          _formatCurrency(p.collectedAmount),
                          _formatCurrency(p.isVoided ? 0 : p.outstandingAmount),
                          p.status,
                        ])
                    .toList(),
            headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: tableBorderColor, width: 0.5)),
            ),
          ),

          _buildSignOff(),
        ],
      ),
    );

    return pdf.save();
  }

  // 2. OCCUPANCY & TENANT ROSTER REPORT
  Future<Uint8List> generateOccupancyRosterPdf() async {
    final pdf = pw.Document();
    final controller = OwnerController.instance;
    final rooms = controller.rooms;
    final tenants = controller.tenants;

    final totalCapacity = rooms.fold<int>(0, (sum, r) => sum + r.capacity);
    final totalOccupied = rooms.fold<int>(0, (sum, r) => sum + r.occupied);
    final occupancyPct = totalCapacity > 0
        ? (totalOccupied / totalCapacity * 100).toStringAsFixed(1)
        : '0';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildReportHeader(
          'Dormitory Occupancy & Tenant Roster',
          'Active rooms: ${rooms.length} • Bed capacity: $totalCapacity • Active tenants: ${tenants.length}',
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          // KPI Metric Row
          pw.Row(
            children: [
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Total Rooms', '${rooms.length} Rooms',
                      color: primaryColor)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Bed Capacity', '$totalCapacity Beds',
                      color: PdfColors.blue800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Occupied Beds', '$totalOccupied Beds',
                      color: PdfColors.green800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard('Occupancy Rate', '$occupancyPct%',
                      color: secondaryColor)),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('ROOM-BY-ROOM CENSUS',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Room',
              'Floor',
              'Capacity',
              'Occupied',
              'Vacant',
              'Status'
            ],
            data: rooms
                .map((r) => [
                      'Room ${r.roomNumber}',
                      r.floor.isNotEmpty ? r.floor : 'Floor 1',
                      '${r.capacity} beds',
                      '${r.occupied} occupied',
                      '${r.capacity - r.occupied} available',
                      r.status,
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
          pw.SizedBox(height: 16),

          pw.Text('RESIDENT DIRECTORY',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Resident Name',
              'Room',
              'Bed Space',
              'Contact Number',
              'Emergency Contact',
              'Emergency Phone'
            ],
            data: tenants
                .map((t) => [
                      t.name,
                      t.room.isNotEmpty ? 'Room ${t.room}' : 'Unassigned',
                      t.bedSpace.isNotEmpty ? t.bedSpace : '-',
                      t.phone.isNotEmpty ? t.phone : 'Not provided',
                      t.guardianName.isNotEmpty ? t.guardianName : 'None',
                      t.guardianPhone.isNotEmpty ? t.guardianPhone : '-',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),

          _buildSignOff(),
        ],
      ),
    );

    return pdf.save();
  }

  // 3. MAINTENANCE & REPAIRS REPORT
  Future<Uint8List> generateMaintenanceReportPdf() async {
    final pdf = pw.Document();
    final reports = await const StaffMaintenanceService().listReports();

    final openCount = reports.where((r) => r.isOpen).length;
    final inProgressCount = reports.where((r) => r.isInProgress).length;
    final resolvedCount = reports.where((r) => r.isResolved).length;
    final urgentCount =
        reports.where((r) => r.isOpen && r.isHighUrgency).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildReportHeader(
          'Facility Maintenance & Work Orders Log',
          'Live database-backed work orders • ${reports.length} record(s)',
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryCard(
                  'Open Requests',
                  '$openCount Open',
                  color: PdfColors.amber800,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildSummaryCard(
                  'In Progress',
                  '$inProgressCount In Progress',
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildSummaryCard(
                  'Resolved',
                  '$resolvedCount Resolved',
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildSummaryCard(
                  'High Priority',
                  '$urgentCount Urgent',
                  color: PdfColors.red800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'MAINTENANCE WORK ORDER LOG',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Report Date',
              'Tenant',
              'Category',
              'Location',
              'Urgency',
              'Status',
              'Description',
              'Staff Notes',
            ],
            data: reports.isEmpty
                ? [
                    [
                      'No maintenance issues recorded',
                      '',
                      '',
                      '',
                      '',
                      '',
                      '',
                      '',
                    ]
                  ]
                : reports
                    .map(
                      (r) => [
                        _formatDate(r.createdAt),
                        r.tenantName,
                        r.category,
                        r.location,
                        r.urgency.toUpperCase(),
                        r.statusLabel,
                        _truncate(r.description, 45),
                        r.notes.isNotEmpty ? _truncate(r.notes, 45) : '-',
                      ],
                    )
                    .toList(),
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
          ),
          _buildSignOff(),
        ],
      ),
    );

    return pdf.save();
  }

  // 4. CONDUCT & VIOLATION REPORT
  Future<Uint8List> generateConductViolationReportPdf() async {
    final pdf = pw.Document();
    const service = ConductCaseService();
    final cases = await service.listStaffCases();

    final evidenceByCase = <String, List<ConductCaseEvidence>>{};
    final warningsByCase = <String, List<ConductCaseWarning>>{};

    for (final record in cases) {
      evidenceByCase[record.id] = await service.listEvidence(record.id);
      warningsByCase[record.id] = await service.listStaffWarnings(record.id);
    }

    final openCount = cases.where((c) => !conductCaseIsClosed(c.status)).length;
    final underReviewCount =
        cases.where((c) => c.status == 'under_review').length;
    final closedCount =
        cases.where((c) => conductCaseIsClosed(c.status)).length;
    final evidenceCount = evidenceByCase.values.fold<int>(
      0,
      (sum, entries) => sum + entries.length,
    );

    final evidenceRows = <List<String>>[];
    final warningRows = <List<String>>[];

    for (final record in cases) {
      for (final evidence
          in evidenceByCase[record.id] ?? const <ConductCaseEvidence>[]) {
        evidenceRows.add([
          _formatDate(evidence.createdAt),
          record.tenantName ?? 'Tenant',
          _truncate(record.title, 36),
          evidence.originalName,
          evidence.caption.isEmpty ? '-' : _truncate(evidence.caption, 60),
        ]);
      }
      for (final warning
          in warningsByCase[record.id] ?? const <ConductCaseWarning>[]) {
        warningRows.add([
          _formatDate(warning.issuedAt),
          record.tenantName ?? 'Tenant',
          _truncate(record.title, 36),
          _truncate(warning.message, 80),
        ]);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildReportHeader(
          'Resident Conduct & Violation Cases',
          'Live disciplinary records • Investigation status, evidence, warnings, and outcomes',
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryCard(
                  'Total Cases',
                  '${cases.length} Cases',
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildSummaryCard(
                  'Open Cases',
                  '$openCount Open',
                  color: PdfColors.amber800,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildSummaryCard(
                  'Under Review',
                  '$underReviewCount Reviewing',
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildSummaryCard(
                  'Closed Cases',
                  '$closedCount Closed',
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildSummaryCard(
                  'Evidence Files',
                  '$evidenceCount Files',
                  color: secondaryColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'CONDUCT & VIOLATION CASE REGISTER',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Incident',
              'Tenant',
              'Category',
              'Investigation Status',
              'Source',
              'Case / Description',
              'Evidence',
              'Warnings',
              'Outcome / Resolution',
            ],
            data: cases.isEmpty
                ? [
                    [
                      'No conduct cases recorded',
                      '',
                      '',
                      '',
                      '',
                      '',
                      '',
                      '',
                      '',
                    ]
                  ]
                : cases
                    .map(
                      (record) => [
                        _formatDate(record.incidentAt),
                        record.tenantName ?? 'Tenant',
                        conductCategoryLabel(record.category),
                        conductStatusLabel(record.status),
                        conductSourceLabel(record.sourceModule ?? 'manual'),
                        '${_truncate(record.title, 34)}\n${_truncate(record.description, 55)}',
                        '${evidenceByCase[record.id]?.length ?? 0}',
                        '${warningsByCase[record.id]?.length ?? 0}',
                        record.terminationReviewReason.isNotEmpty
                            ? _truncate(record.terminationReviewReason, 60)
                            : record.resolutionNotes.isNotEmpty
                                ? _truncate(record.resolutionNotes, 60)
                                : '-',
                      ],
                    )
                    .toList(),
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 6.2),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 4,
            ),
          ),
          if (evidenceRows.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'EVIDENCE REGISTER',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Added', 'Tenant', 'Case', 'Evidence File', 'Caption'],
              data: evidenceRows,
              headerStyle: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
            ),
          ],
          if (warningRows.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'FORMAL WARNING REGISTER',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Issued', 'Tenant', 'Case', 'Warning'],
              data: warningRows,
              headerStyle: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
            ),
          ],
          _buildSignOff(),
        ],
      ),
    );

    return pdf.save();
  }

  // 5. SECURITY, GATE & CURFEW REPORT
  Future<Uint8List> generateCurfewGateReportPdf() async {
    final pdf = pw.Document();
    final controller = OwnerController.instance;
    final gateEvents = controller.gateEvents;
    final curfewRequests = controller.curfewRequests;

    final inCount = gateEvents.where((e) => e.direction == 'IN').length;
    final outCount = gateEvents.where((e) => e.direction == 'OUT').length;
    final flaggedCount = gateEvents.where((e) => e.status == 'Flagged').length;
    final approvedPasses =
        curfewRequests.where((r) => r.status == 'approved').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildReportHeader(
          'Security, Gate & Curfew Presence Audit Log',
          'Gate Events: ${gateEvents.length} | Curfew Requests: ${curfewRequests.length}',
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          // KPI Grid
          pw.Row(
            children: [
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Total Entries (IN)', '$inCount Entries',
                      color: PdfColors.green800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Total Exits (OUT)', '$outCount Exits',
                      color: PdfColors.blue800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Flagged Violations', '$flaggedCount Flagged',
                      color: PdfColors.red800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Approved Passes', '$approvedPasses Approved',
                      color: secondaryColor)),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('GATE ACCESS AUDIT LOG',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Timestamp',
              'Resident Name',
              'Direction',
              'Status',
              'Verification Method'
            ],
            data: gateEvents
                .map((e) => [
                      '${_formatDate(e.time)} ${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}',
                      e.person,
                      e.direction ?? '-',
                      e.status,
                      e.verification,
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
          pw.SizedBox(height: 16),

          pw.Text('CURFEW EXEMPTION & OVERNIGHT PASSES',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Request Type',
              'Departure',
              'Return Time',
              'Destination',
              'Reason',
              'Status'
            ],
            data: curfewRequests
                .map((c) => [
                      c.requestType.replaceAll('_', ' ').toUpperCase(),
                      _formatDate(c.departureTime),
                      _formatDate(c.expectedReturnTime),
                      c.destination,
                      c.reason.length > 25
                          ? '${c.reason.substring(0, 22)}...'
                          : c.reason,
                      c.status.toUpperCase(),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),

          _buildSignOff(),
        ],
      ),
    );

    return pdf.save();
  }

  // 6. CONSOLIDATED EXECUTIVE OVERVIEW
  Future<Uint8List> generateExecutiveOverviewPdf() async {
    final pdf = pw.Document();
    final controller = OwnerController.instance;

    final rooms = controller.rooms;
    final totalCapacity = rooms.fold<int>(0, (sum, r) => sum + r.capacity);
    final totalOccupied = rooms.fold<int>(0, (sum, r) => sum + r.occupied);
    final occupancyPct = totalCapacity > 0
        ? (totalOccupied / totalCapacity * 100).toStringAsFixed(0)
        : '0';

    final payments = controller.payments;
    final financial = FinancialSnapshot(payments);
    final totalPaid = financial.collected;
    final totalDue = financial.outstanding;

    final maintenance = controller.staffMaintenanceReports;
    final openIssues = maintenance.where((m) => m.isOpen).length;
    final gateEvents = controller.gateEvents;
    final flaggedCurfew = gateEvents.where((e) => e.status == 'Flagged').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildReportHeader(
          'Executive Performance Overview',
          'Consolidated Monthly Administrative & Operations Review',
        ),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          pw.Text('EXECUTIVE SUMMARY & OPERATIONAL HEALTH',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor)),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                  child: _buildSummaryCard('Occupancy Rate',
                      '$occupancyPct% ($totalOccupied/$totalCapacity Beds)',
                      color: primaryColor)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Revenue Collected', _formatCurrency(totalPaid),
                      color: PdfColors.green800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Outstanding Dues', _formatCurrency(totalDue),
                      color: PdfColors.red800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Open Repairs', '$openIssues Pending',
                      color: PdfColors.amber800)),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _buildSummaryCard(
                      'Curfew Flags', '$flaggedCurfew After-Hours',
                      color: secondaryColor)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBgColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: tableBorderColor),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Management Highlights & Operational Notes',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
                pw.SizedBox(height: 6),
                pw.Bullet(
                    text:
                        'Dormitory occupancy stands at $occupancyPct% across ${rooms.length} active residential rooms.'),
                pw.Bullet(
                    text:
                        'Total verified collection in ledger currently equals ${_formatCurrency(totalPaid)}.'),
                pw.Bullet(
                    text:
                        '$openIssues active maintenance work orders are currently tracked by custodial staff.'),
                pw.Bullet(
                    text:
                        'GPS geofencing tripwire recorded $flaggedCurfew after-hours curfew events requiring staff acknowledgment.'),
              ],
            ),
          ),
          _buildSignOff(),
        ],
      ),
    );

    return pdf.save();
  }

  /// Opens the PDF preview sheet or window across Web and Mobile.
  void openReportPreview(
    BuildContext context, {
    required String title,
    required String fileName,
    required Future<Uint8List> Function() documentBuilder,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF6B1D2F),
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) => documentBuilder(),
            pdfFileName: fileName,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }
}
