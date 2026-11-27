import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/document_delivery.dart';
import '../../../core/utils/formatters.dart';
import '../../portfolio/domain/portfolio_summary.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../users/domain/user_profile.dart';
import '../domain/client_report_row.dart';

/// Builds Fundmf's client documents — CAMS transaction ledger, portfolio
/// statement and holdings schedule — as CSV or PDF, then hands them to the
/// platform through [DocumentDelivery] (native share sheet on mobile, a real
/// browser download on web).
class ReportExporter {
  const ReportExporter({this.delivery = const DocumentDelivery()});

  final DocumentDelivery delivery;

  // ------------------------------------------------------------- ledger ----

  Future<DeliveryResult> exportTransactionLedgerCsv({
    required List<FundTransaction> transactions,
    required UserProfile profile,
  }) {
    final rows = <List<String>>[
      <String>['FUNDMF - CAMS transaction ledger'],
      <String>['Client', profile.fullName],
      <String>['Client ID', profile.clientId],
      <String>['PAN', profile.pan],
      <String>['Email', profile.email],
      <String>['Phone', profile.phone],
      <String>['Generated', Formatters.timestamp(DateTime.now())],
      <String>['Rows', '${transactions.length}'],
      <String>[],
      <String>[
        'Date',
        'Scheme',
        'Folio',
        'Transaction ID',
        'Type',
        'Units',
        'NAV',
        'Amount (INR)',
      ],
      for (final transaction in transactions)
        <String>[
          Formatters.isoDate(transaction.transactionDate),
          transaction.schemeName,
          transaction.folioNumber,
          transaction.transactionId,
          transaction.kind.displayName,
          transaction.units.toStringAsFixed(3),
          transaction.purchaseNav.toStringAsFixed(4),
          transaction.amount.toStringAsFixed(2),
        ],
    ];

    return _deliver(
      bytes: _encodeCsv(rows),
      fileName: 'fundmf-transaction-ledger-${_fileStamp()}.csv',
      mimeType: 'text/csv',
      title: 'Transaction ledger',
      subject: 'FUNDMF transaction ledger - ${profile.fullName}',
    );
  }

  Future<DeliveryResult> exportTransactionLedgerPdf({
    required List<FundTransaction> transactions,
    required UserProfile profile,
  }) async {
    final document = pw.Document(title: 'Fundmf transaction ledger');
    final inflow = transactions
        .where((transaction) => transaction.kind.isInflow)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final outflow = transactions
        .where((transaction) => transaction.kind.isOutflow)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
        footer: _footer,
        build: (context) => <pw.Widget>[
          _masthead('CAMS TRANSACTION LEDGER'),
          pw.SizedBox(height: 16),
          _clientBlock(profile),
          pw.SizedBox(height: 14),
          _metricStrip(<(String, String, PdfColor?)>[
            ('Transactions', '${transactions.length}', null),
            ('Purchases', Formatters.amountWithoutSymbol(inflow), _green),
            ('Redemptions', Formatters.amountWithoutSymbol(outflow), _red),
            ('Net invested', Formatters.amountWithoutSymbol(inflow - outflow), null),
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Ledger'),
          pw.SizedBox(height: 6),
          _table(
            headers: const <String>[
              'Date',
              'Scheme',
              'Folio',
              'Type',
              'Units',
              'NAV',
              'Amount (INR)',
            ],
            flex: const <double>[1.1, 3.4, 1.3, 1.2, 1.1, 1.0, 1.4],
            rightAligned: const <int>{4, 5, 6},
            rows: <List<String>>[
              for (final transaction in transactions)
                <String>[
                  Formatters.isoDate(transaction.transactionDate),
                  transaction.schemeName,
                  transaction.folioNumber.isEmpty ? '-' : transaction.folioNumber,
                  transaction.kind.displayName,
                  transaction.units.toStringAsFixed(3),
                  transaction.purchaseNav.toStringAsFixed(4),
                  Formatters.amountWithoutSymbol(transaction.amount),
                ],
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'All amounts are in Indian Rupees. Source: CAMS / KFintech '
            'consolidated account statements. Generated '
            '${Formatters.timestamp(DateTime.now())}.',
            style: pw.TextStyle(fontSize: 7, color: _muted, lineSpacing: 1.4),
          ),
        ],
      ),
    );

    return _deliver(
      bytes: await document.save(),
      fileName: 'fundmf-transaction-ledger-${_fileStamp()}.pdf',
      mimeType: 'application/pdf',
      title: 'Transaction ledger',
      subject: 'FUNDMF transaction ledger - ${profile.fullName}',
    );
  }

  // ---------------------------------------------------------- statement ----

  Future<DeliveryResult> exportPortfolioStatementPdf({
    required PortfolioSummary summary,
    required UserProfile profile,
  }) async {
    final document = pw.Document(title: 'Fundmf portfolio statement');
    final pnlColor = summary.absolutePnl >= 0 ? _green : _red;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
        footer: _footer,
        build: (context) => <pw.Widget>[
          _masthead('PORTFOLIO STATEMENT'),
          pw.SizedBox(height: 16),
          _clientBlock(profile),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _ink,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      'CURRENT PORTFOLIO VALUE',
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: _gold,
                        letterSpacing: 1.2,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'INR ${Formatters.amountWithoutSymbol(summary.currentValue)}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text(
                      'UNREALISED ${summary.absolutePnl >= 0 ? 'GAIN' : 'LOSS'}',
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey400,
                        letterSpacing: 1.1,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${summary.absolutePnl >= 0 ? '+' : '-'}INR '
                      '${Formatters.amountWithoutSymbol(summary.absolutePnl.abs())}'
                      '  (${Formatters.signedPercent(summary.returnPercent)})',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _metricStrip(<(String, String, PdfColor?)>[
            ('Total invested', Formatters.amountWithoutSymbol(summary.totalInvested), null),
            ('Schemes held', '${summary.holdings.length}', null),
            ('Units', Formatters.units(summary.totalUnits), null),
            ('CAGR', Formatters.signedPercent(summary.cagrPercent), pnlColor),
          ]),
          pw.SizedBox(height: 18),
          _sectionTitle('Scheme-wise holdings'),
          pw.SizedBox(height: 6),
          if (summary.holdings.isEmpty)
            pw.Text(
              'No active holdings were found for this PAN.',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            )
          else
            _table(
              headers: const <String>[
                'Scheme',
                'Folio',
                'Units',
                'Avg NAV',
                'NAV',
                'Invested',
                'Value',
                'P&L',
                'Alloc',
              ],
              flex: const <double>[3.4, 1.2, 1.0, 0.9, 0.9, 1.3, 1.3, 1.3, 0.7],
              rightAligned: const <int>{2, 3, 4, 5, 6, 7, 8},
              rows: <List<String>>[
                for (final holding in summary.holdings)
                  <String>[
                    holding.schemeName,
                    holding.folioLabel,
                    holding.units.toStringAsFixed(3),
                    Formatters.nav(holding.averageNav),
                    Formatters.nav(holding.currentNav),
                    Formatters.amountWithoutSymbol(holding.investedAmount),
                    Formatters.amountWithoutSymbol(holding.currentValue),
                    Formatters.amountWithoutSymbol(holding.pnl),
                    holding.allocationPercent.toStringAsFixed(1),
                  ],
              ],
              footer: <List<String>>[
                <String>[
                  'Total',
                  '',
                  Formatters.units(summary.totalUnits),
                  '',
                  '',
                  Formatters.amountWithoutSymbol(summary.totalInvested),
                  Formatters.amountWithoutSymbol(summary.currentValue),
                  Formatters.amountWithoutSymbol(summary.absolutePnl),
                  '100.0',
                ],
              ],
            ),
          pw.SizedBox(height: 20),
          _sectionTitle('Valuation notes'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Holdings are valued at the latest AMFI NAV published by the '
            'scheme. Cost basis follows the average-cost method: every '
            'redemption removes units at the running average NAV. '
            '${summary.hasLiveNav ? 'Live NAVs were available for this statement.' : 'Where a live NAV was unavailable, the average cost NAV is used.'}'
            '${summary.closedSchemes > 0 ? ' ${summary.closedSchemes} fully redeemed scheme(s) are excluded from the holdings above.' : ''}',
            style: pw.TextStyle(fontSize: 7.5, color: _muted, lineSpacing: 1.5),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: 0.5),
              color: _wash,
            ),
            child: pw.Text(
              'This statement is generated from consolidated CAMS/KFintech '
              'account statements for informational purposes only. It is not a '
              'tax document and not investment advice. Mutual fund investments '
              'are subject to market risk.',
              style: pw.TextStyle(fontSize: 6.8, color: _muted, lineSpacing: 1.5),
            ),
          ),
        ],
      ),
    );

    return _deliver(
      bytes: await document.save(),
      fileName: 'fundmf-portfolio-statement-${_fileStamp()}.pdf',
      mimeType: 'application/pdf',
      title: 'Portfolio statement',
      subject: 'FUNDMF portfolio statement - ${profile.fullName}',
    );
  }

  Future<DeliveryResult> exportHoldingsCsv({
    required PortfolioSummary summary,
    required UserProfile profile,
  }) {
    final rows = <List<String>>[
      <String>['FUNDMF - Holdings schedule'],
      <String>['Client', profile.fullName],
      <String>['Client ID', profile.clientId],
      <String>['PAN', profile.pan],
      <String>['Email', profile.email],
      <String>['Generated', Formatters.timestamp(DateTime.now())],
      <String>[],
      <String>[
        'Scheme',
        'AMFI code',
        'Folio',
        'Units',
        'Average NAV',
        'Current NAV',
        'Invested (INR)',
        'Current value (INR)',
        'P&L (INR)',
        'P&L %',
        'Allocation %',
        'CAGR %',
      ],
      for (final holding in summary.holdings)
        <String>[
          holding.schemeName,
          holding.schemeCode > 0 ? '${holding.schemeCode}' : '',
          holding.folioLabel,
          holding.units.toStringAsFixed(3),
          holding.averageNav.toStringAsFixed(4),
          holding.currentNav.toStringAsFixed(4),
          holding.investedAmount.toStringAsFixed(2),
          holding.currentValue.toStringAsFixed(2),
          holding.pnl.toStringAsFixed(2),
          holding.pnlPercent.toStringAsFixed(2),
          holding.allocationPercent.toStringAsFixed(2),
          holding.cagrPercent.toStringAsFixed(2),
        ],
      <String>[],
      <String>['Total', '', '', summary.totalUnits.toStringAsFixed(3), '', '',
        summary.totalInvested.toStringAsFixed(2),
        summary.currentValue.toStringAsFixed(2),
        summary.absolutePnl.toStringAsFixed(2),
        summary.returnPercent.toStringAsFixed(2), '100.00',
        summary.cagrPercent.toStringAsFixed(2)],
    ];

    return _deliver(
      bytes: _encodeCsv(rows),
      fileName: 'fundmf-holdings-${_fileStamp()}.csv',
      mimeType: 'text/csv',
      title: 'Holdings schedule',
      subject: 'FUNDMF holdings schedule - ${profile.fullName}',
    );
  }

  // ------------------------------------------------------------- admin ----

  Future<DeliveryResult> exportClientDirectoryCsv({
    required List<ClientReportRow> rows,
  }) {
    final csvRows = <List<String>>[
      <String>['FUNDMF - Client directory'],
      <String>['Generated', Formatters.timestamp(DateTime.now())],
      <String>['Clients', '${rows.length}'],
      <String>[],
      <String>[
        'Client ID',
        'Name',
        'Email',
        'PAN',
        'Phone',
        'Status',
        'Schemes',
        'Invested (INR)',
        'Current value (INR)',
        'P&L (INR)',
        'Return %',
      ],
      for (final row in rows)
        <String>[
          row.clientId,
          row.name,
          row.email,
          row.pan,
          row.phone,
          row.status,
          '${row.schemes}',
          row.invested.toStringAsFixed(2),
          row.currentValue.toStringAsFixed(2),
          row.pnl.toStringAsFixed(2),
          row.returnPercent.toStringAsFixed(2),
        ],
      <String>[],
      <String>[
        'Total',
        '',
        '',
        '',
        '',
        '${rows.length} clients',
        '',
        rows.fold<double>(0, (sum, row) => sum + row.invested).toStringAsFixed(2),
        rows.fold<double>(0, (sum, row) => sum + row.currentValue).toStringAsFixed(2),
        rows.fold<double>(0, (sum, row) => sum + row.pnl).toStringAsFixed(2),
        '',
      ],
    ];

    return _deliver(
      bytes: _encodeCsv(csvRows),
      fileName: 'fundmf-client-directory-${_fileStamp()}.csv',
      mimeType: 'text/csv',
      title: 'Client directory',
      subject: 'FUNDMF client directory',
    );
  }

  Future<DeliveryResult> exportClientDirectoryPdf({
    required List<ClientReportRow> rows,
  }) async {
    final document = pw.Document(title: 'Fundmf client directory');
    final invested = rows.fold<double>(0, (sum, row) => sum + row.invested);
    final current = rows.fold<double>(0, (sum, row) => sum + row.currentValue);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
        footer: _footer,
        build: (context) => <pw.Widget>[
          _masthead('CLIENT DIRECTORY'),
          pw.SizedBox(height: 16),
          _metricStrip(<(String, String, PdfColor?)>[
            ('Clients', '${rows.length}', null),
            ('Assets managed', Formatters.amountWithoutSymbol(current), null),
            ('Total invested', Formatters.amountWithoutSymbol(invested), null),
            ('Unrealised P&L', Formatters.amountWithoutSymbol(current - invested),
                current - invested >= 0 ? _green : _red),
          ]),
          pw.SizedBox(height: 16),
          _table(
            headers: const <String>[
              'Client ID',
              'Name',
              'Email',
              'PAN',
              'Status',
              'Schemes',
              'Invested',
              'Current value',
              'P&L',
              'Return',
            ],
            flex: const <double>[1.3, 2.2, 2.8, 1.2, 1.2, 0.8, 1.3, 1.4, 1.3, 0.9],
            rightAligned: const <int>{5, 6, 7, 8, 9},
            rows: <List<String>>[
              for (final row in rows)
                <String>[
                  row.clientId,
                  row.name,
                  row.email,
                  row.pan,
                  row.status,
                  '${row.schemes}',
                  Formatters.amountWithoutSymbol(row.invested),
                  Formatters.amountWithoutSymbol(row.currentValue),
                  Formatters.amountWithoutSymbol(row.pnl),
                  Formatters.signedPercent(row.returnPercent),
                ],
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Clients without imported CAMS transactions are shown with zero '
            'balances. Valuations use the latest AMFI NAV available at the '
            'time of generation (${Formatters.timestamp(DateTime.now())}).',
            style: pw.TextStyle(fontSize: 7, color: _muted, lineSpacing: 1.4),
          ),
        ],
      ),
    );

    return _deliver(
      bytes: await document.save(),
      fileName: 'fundmf-client-directory-${_fileStamp()}.pdf',
      mimeType: 'application/pdf',
      title: 'Client directory',
      subject: 'FUNDMF client directory',
    );
  }

  // ------------------------------------------------------------ helpers ----

  Future<DeliveryResult> _deliver({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String title,
    required String subject,
  }) {
    return delivery.deliver(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: '$title generated by Fundmf.',
    );
  }

  Uint8List _encodeCsv(List<List<String>> rows) {
    final body = rows
        .map((row) => row.map(_escapeCsv).join(','))
        .join('\r\n');
    // UTF-8 BOM so Excel opens Indian-grouped amounts correctly.
    return Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(body)]);
  }

  String _escapeCsv(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _fileStamp() => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

  pw.Widget _masthead(String documentTitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'FUNDMF',
                  style: pw.TextStyle(
                    fontSize: 19,
                    letterSpacing: 3,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'WEALTH MANAGEMENT',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    letterSpacing: 1.8,
                    color: _gold,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: <pw.Widget>[
                pw.Text(
                  documentTitle,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'As on ${Formatters.date(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 7.5, color: _muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 9),
        pw.Container(height: 1.1, color: _ink),
        pw.SizedBox(height: 2.5),
        pw.Container(width: 70, height: 1.8, color: _gold),
      ],
    );
  }

  pw.Widget _clientBlock(UserProfile profile) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                profile.fullName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                profile.email,
                style: pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                profile.phone.isEmpty ? '-' : profile.phone,
                style: pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              _fieldLine('CLIENT ID', profile.clientId.isEmpty ? '-' : profile.clientId),
              pw.SizedBox(height: 2),
              _fieldLine('PAN', profile.pan.isEmpty ? '-' : profile.pan),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _fieldLine(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: <pw.Widget>[
        pw.Text(
          '$label  ',
          style: pw.TextStyle(
            fontSize: 6.5,
            letterSpacing: 0.8,
            color: _muted,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8.5,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _metricStrip(List<(String, String, PdfColor?)> metrics) {
    final children = <pw.Widget>[];
    for (var index = 0; index < metrics.length; index++) {
      final (label, value, color) = metrics[index];
      if (index > 0) children.add(pw.SizedBox(width: 6));
      children.add(
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: pw.BoxDecoration(
              color: _wash,
              border: pw.Border.all(color: _line, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 6,
                    letterSpacing: 0.9,
                    color: _muted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: color ?? _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return pw.Row(children: children);
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Row(
      children: <pw.Widget>[
        pw.Container(width: 14, height: 1.6, color: _gold),
        pw.SizedBox(width: 6),
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7.5,
            letterSpacing: 1.1,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ],
    );
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> flex,
    Set<int> rightAligned = const <int>{},
    List<List<String>> footer = const <List<String>>[],
  }) {
    pw.TableRow buildRow(
      List<String> cells, {
      required bool isHeader,
      required bool isFooter,
    }) {
      return pw.TableRow(
        decoration: isHeader
            ? pw.BoxDecoration(color: _ink)
            : isFooter
                ? pw.BoxDecoration(color: _wash)
                : null,
        children: <pw.Widget>[
          for (var index = 0; index < cells.length; index++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Container(
                alignment: rightAligned.contains(index) && !isHeader
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
                child: pw.Text(
                  cells[index],
                  style: pw.TextStyle(
                    fontSize: isHeader ? 6.6 : 7.2,
                    color: isHeader
                        ? PdfColors.white
                        : (isFooter ? _ink : _ink),
                    fontWeight: isHeader || isFooter
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return pw.Table(
      columnWidths: <int, pw.TableColumnWidth>{
        for (var index = 0; index < flex.length; index++)
          index: pw.FlexColumnWidth(flex[index]),
      },
      border: pw.TableBorder(
        top: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
        horizontalInside: pw.BorderSide(color: _line, width: 0.4),
      ),
      children: <pw.TableRow>[
        buildRow(headers, isHeader: true, isFooter: false),
        for (final row in rows) buildRow(row, isHeader: false, isFooter: false),
        for (final row in footer) buildRow(row, isHeader: false, isFooter: true),
      ],
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            'Fundmf  |  Generated from CAMS / KFintech statements and AMFI '
            'NAVs  |  Not investment advice',
            style: pw.TextStyle(fontSize: 6.2, color: _muted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 6.2, color: _muted),
          ),
        ],
      ),
    );
  }
}

final PdfColor _ink = PdfColor.fromInt(0xFF101C2E);
final PdfColor _gold = PdfColor.fromInt(0xFFB0863F);
final PdfColor _muted = PdfColor.fromInt(0xFF6C7787);
final PdfColor _line = PdfColor.fromInt(0xFFE5E3DD);
final PdfColor _wash = PdfColor.fromInt(0xFFF7F6F2);
final PdfColor _green = PdfColor.fromInt(0xFF17604A);
final PdfColor _red = PdfColor.fromInt(0xFF8A332B);
