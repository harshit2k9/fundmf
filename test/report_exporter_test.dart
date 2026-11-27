import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundmf/core/utils/document_delivery.dart';
import 'package:fundmf/features/portfolio/domain/portfolio_summary.dart';
import 'package:fundmf/features/portfolio/domain/scheme_holding.dart';
import 'package:fundmf/features/reports/domain/client_report_row.dart';
import 'package:fundmf/features/reports/services/report_exporter.dart';
import 'package:fundmf/features/transactions/domain/transaction_model.dart';
import 'package:fundmf/features/users/domain/user_profile.dart';

/// Captures the generated document instead of talking to the platform, so the
/// export pipeline can be verified without a share sheet or a browser.
class _CapturingDelivery implements DocumentDelivery {
  Uint8List? bytes;
  String? fileName;
  String? mimeType;

  @override
  Future<DeliveryResult> deliver({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
    required String text,
  }) async {
    this.bytes = bytes;
    this.fileName = fileName;
    this.mimeType = mimeType;
    return const DeliveryResult(delivered: true, location: 'Downloads');
  }
}

const _profile = UserProfile(
  email: 'asha@example.com',
  fullName: 'Asha Menon',
  pan: 'ABCDE1234F',
  phone: '9876543210',
  clientId: 'FMF-2026-00042',
);

final _transactions = <FundTransaction>[
  FundTransaction(
    id: 'T1',
    transactionId: 'T1',
    pan: 'ABCDE1234F',
    schemeName: 'Axis Bluechip Fund - Growth',
    transactionDate: DateTime(2025, 4, 12),
    kind: TransactionKind.purchase,
    amount: 25000,
    units: 512.345,
    purchaseNav: 48.7951,
    folioNumber: '91001234',
    schemeCode: 120503,
  ),
  FundTransaction(
    id: 'T2',
    transactionId: 'T2',
    pan: 'ABCDE1234F',
    schemeName: 'Axis Bluechip Fund - Growth',
    transactionDate: DateTime(2025, 5, 12),
    kind: TransactionKind.sip,
    amount: 25000,
    units: 498.123,
    purchaseNav: 50.1884,
    folioNumber: '91001234',
    schemeCode: 120503,
  ),
];

const _holding = SchemeHolding(
  schemeCode: 120503,
  schemeName: 'Axis Bluechip Fund - Growth',
  folios: <String>['91001234'],
  units: 1010.468,
  investedAmount: 50000,
  averageNav: 49.4821,
  currentNav: 54.21,
  currentValue: 54777.37,
  pnl: 4777.37,
  pnlPercent: 9.55,
  allocationPercent: 100,
  cagrPercent: 14.2,
  navAvailable: true,
);

final _summary = PortfolioSummary(
  totalInvested: 50000,
  currentValue: 54777.37,
  absolutePnl: 4777.37,
  returnPercent: 9.55,
  cagrPercent: 14.2,
  totalUnits: 1010.468,
  holdings: const <SchemeHolding>[_holding],
  hasLiveNav: true,
  asOf: DateTime(2025, 6, 1),
);

void main() {
  group('ReportExporter', () {
    test('writes a transaction ledger CSV with a BOM and the ledger rows',
        () async {
      final delivery = _CapturingDelivery();
      final result = await ReportExporter(delivery: delivery)
          .exportTransactionLedgerCsv(
        transactions: _transactions,
        profile: _profile,
      );

      expect(result.delivered, isTrue);
      expect(delivery.mimeType, 'text/csv');
      expect(delivery.fileName, endsWith('.csv'));

      final bytes = delivery.bytes!;
      expect(bytes.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF]);
      final csv = utf8.decode(bytes.sublist(3));
      expect(csv, contains('FUNDMF - CAMS transaction ledger'));
      expect(csv, contains('Asha Menon'));
      expect(csv, contains('Axis Bluechip Fund - Growth'));
      expect(csv, contains('SIP'));
      expect(csv, contains('25000.00'));
    });

    test('writes a PDF transaction ledger', () async {
      final delivery = _CapturingDelivery();
      await ReportExporter(delivery: delivery).exportTransactionLedgerPdf(
        transactions: _transactions,
        profile: _profile,
      );

      expect(delivery.mimeType, 'application/pdf');
      expect(delivery.fileName, endsWith('.pdf'));
      expect(utf8.decode(delivery.bytes!.sublist(0, 4)), '%PDF');
      expect(delivery.bytes!.length, greaterThan(1000));
    });

    test('writes a portfolio statement PDF', () async {
      final delivery = _CapturingDelivery();
      await ReportExporter(delivery: delivery).exportPortfolioStatementPdf(
        summary: _summary,
        profile: _profile,
      );

      expect(delivery.fileName, endsWith('.pdf'));
      expect(utf8.decode(delivery.bytes!.sublist(0, 4)), '%PDF');
    });

    test('writes a holdings schedule CSV with scheme and totals', () async {
      final delivery = _CapturingDelivery();
      await ReportExporter(delivery: delivery).exportHoldingsCsv(
        summary: _summary,
        profile: _profile,
      );

      final csv = utf8.decode(delivery.bytes!.sublist(3));
      expect(csv, contains('AMFI code'));
      expect(csv, contains('120503'));
      expect(csv, contains('Axis Bluechip Fund - Growth'));
      expect(csv, contains('54777.37'));
    });

    test('writes a client directory CSV with the book of business', () async {
      final delivery = _CapturingDelivery();
      await ReportExporter(delivery: delivery).exportClientDirectoryCsv(
        rows: const <ClientReportRow>[
          ClientReportRow(
            clientId: 'FMF-2026-00042',
            name: 'Asha Menon',
            email: 'asha@example.com',
            pan: 'ABCDE1234F',
            phone: '9876543210',
            status: 'Active',
            schemes: 1,
            invested: 50000,
            currentValue: 54777.37,
            pnl: 4777.37,
          ),
        ],
      );

      final csv = utf8.decode(delivery.bytes!.sublist(3));
      expect(csv, contains('FUNDMF - Client directory'));
      expect(csv, contains('Asha Menon'));
      expect(csv, contains('54777.37'));
    });
  });
}
