import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../users/domain/user_profile.dart';
import '../domain/transaction_model.dart';

/// Builds the transaction report as CSV or PDF and hands it to the platform
/// share sheet (which also covers "Save to Files"/download on web).
class ReportExporter {
  const ReportExporter();

  Future<ShareResult> shareCsv({
    required List<FundTransaction> transactions,
    required UserProfile profile,
  }) async {
    final bytes = Uint8List.fromList(
      utf8.encode(_buildCsv(transactions, profile)),
    );
    final file = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: 'fundmf-transactions-${_fileStamp()}.csv',
    );
    return SharePlus.instance.share(
      ShareParams(
        files: <XFile>[file],
        subject: 'FUNDMF transactions — ${profile.fullName}',
        text: 'FUNDMF transaction report for ${profile.fullName}.',
      ),
    );
  }

  Future<ShareResult> sharePdf({
    required List<FundTransaction> transactions,
    required UserProfile profile,
  }) async {
    final document = pw.Document();
    final generatedAt = Formatters.timestamp(DateTime.now());

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                'FUNDMF',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.Text(
                'CAMS transaction report',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.blueGrey200, thickness: 0.8),
          pw.SizedBox(height: 6),
          pw.Text(
            profile.fullName,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Client ID ${profile.clientId}   ·   PAN ${profile.pan}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.Text(
            '${profile.email}   ·   ${profile.phone}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const <String>[
              'Date',
              'Scheme',
              'Folio',
              'Type',
              'Units',
              'NAV',
              'Amount (Rs.)',
            ],
            data: <List<String>>[
              for (final transaction in transactions)
                <String>[
                  Formatters.isoDate(transaction.transactionDate),
                  transaction.schemeName,
                  transaction.folioNumber,
                  transaction.kind.displayName,
                  transaction.units.toStringAsFixed(3),
                  transaction.purchaseNav.toStringAsFixed(4),
                  Formatters.amountWithoutSymbol(transaction.amount),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey900,
            ),
            headerAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignments: <int, pw.Alignment>{
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.4,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '${transactions.length} transactions  ·  generated $generatedAt  '
            '·  Source: CAMS consolidated statements',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: 'fundmf-transactions-${_fileStamp()}.pdf',
    );
    return SharePlus.instance.share(
      ShareParams(
        files: <XFile>[file],
        subject: 'FUNDMF transactions — ${profile.fullName}',
        text: 'FUNDMF transaction report for ${profile.fullName}.',
      ),
    );
  }

  /// CSV includes a short header block so the file is self-describing when the
  /// investor forwards it to their CA.
  String _buildCsv(List<FundTransaction> transactions, UserProfile profile) {
    final rows = <List<String>>[
      <String>['FUNDMF transaction report'],
      <String>['Client', profile.fullName],
      <String>['Client ID', profile.clientId],
      <String>['PAN', profile.pan],
      <String>['Email', profile.email],
      <String>['Phone', profile.phone],
      <String>['Generated', Formatters.timestamp(DateTime.now())],
      <String>[],
      <String>[
        'Date',
        'Scheme',
        'Folio',
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
          transaction.kind.displayName,
          transaction.units.toStringAsFixed(3),
          transaction.purchaseNav.toStringAsFixed(4),
          transaction.amount.toStringAsFixed(2),
        ],
    ];

    return rows
        .map((row) => row.map(_escapeCsv).join(','))
        .join('\r\n');
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
}
