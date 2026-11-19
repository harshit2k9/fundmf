import 'package:flutter_test/flutter_test.dart';
import 'package:fundmf/features/portfolio/domain/nav_quote.dart';
import 'package:fundmf/features/portfolio/domain/portfolio_calculator.dart';
import 'package:fundmf/features/transactions/domain/transaction_model.dart';

FundTransaction txn({
  required String id,
  required DateTime date,
  required TransactionKind kind,
  required double amount,
  required double units,
  double nav = 0,
  int schemeCode = 119551,
  String schemeName = 'Axis Bluechip Fund - Growth',
  String pan = 'ABCDE1234F',
}) {
  return FundTransaction(
    id: id,
    transactionId: id,
    pan: pan,
    schemeName: schemeName,
    schemeCode: schemeCode,
    transactionDate: date,
    kind: kind,
    amount: amount,
    units: units,
    purchaseNav: nav,
  );
}

NavQuote quote(int code, double nav) => NavQuote(
      schemeCode: code,
      schemeName: 'Axis Bluechip Fund - Growth',
      fundHouse: 'Axis Mutual Fund',
      nav: nav,
      date: DateTime(2026, 11, 18),
    );

void main() {
  const calculator = PortfolioCalculator();

  group('PortfolioCalculator', () {
    test('computes invested, value, P&L and return from a purchase', () {
      final summary = calculator.calculate(
        transactions: <FundTransaction>[
          txn(
            id: 'T1',
            date: DateTime(2026, 1, 10),
            kind: TransactionKind.purchase,
            amount: 100000,
            units: 1000,
            nav: 100,
          ),
        ],
        navByKey: <String, NavQuote>{
          PortfolioCalculator.schemeKeyForCode(119551): quote(119551, 125),
        },
      );

      expect(summary.totalInvested, 100000);
      expect(summary.currentValue, 125000);
      expect(summary.absolutePnl, 25000);
      expect(summary.returnPercent, 25);
      expect(summary.totalUnits, 1000);
      expect(summary.holdings, hasLength(1));
      expect(summary.holdings.single.averageNav, 100);
      expect(summary.holdings.single.allocationPercent, 100);
      expect(summary.hasLiveNav, isTrue);
    });

    test('accumulates SIP instalments at a weighted average NAV', () {
      final summary = calculator.calculate(
        transactions: <FundTransaction>[
          txn(
            id: 'S1',
            date: DateTime(2026, 1, 5),
            kind: TransactionKind.sip,
            amount: 10000,
            units: 100,
            nav: 100,
          ),
          txn(
            id: 'S2',
            date: DateTime(2026, 2, 5),
            kind: TransactionKind.sip,
            amount: 10000,
            units: 80,
            nav: 125,
          ),
        ],
        navByKey: <String, NavQuote>{
          PortfolioCalculator.schemeKeyForCode(119551): quote(119551, 150),
        },
      );

      expect(summary.totalInvested, 20000);
      expect(summary.totalUnits, closeTo(180, 0.0001));
      expect(summary.holdings.single.averageNav, closeTo(111.1111, 0.001));
      expect(summary.currentValue, closeTo(27000, 0.0001));
      expect(summary.absolutePnl, closeTo(7000, 0.0001));
    });

    test('redemption removes units and the average-cost principal', () {
      final summary = calculator.calculate(
        transactions: <FundTransaction>[
          txn(
            id: 'P1',
            date: DateTime(2026, 1, 10),
            kind: TransactionKind.purchase,
            amount: 100000,
            units: 1000,
            nav: 100,
          ),
          txn(
            id: 'R1',
            date: DateTime(2026, 6, 10),
            kind: TransactionKind.redemption,
            amount: 30000,
            units: 200,
            nav: 150,
          ),
        ],
        navByKey: <String, NavQuote>{
          PortfolioCalculator.schemeKeyForCode(119551): quote(119551, 140),
        },
      );

      expect(summary.totalUnits, closeTo(800, 0.0001));
      expect(summary.totalInvested, closeTo(80000, 0.0001));
      expect(summary.currentValue, closeTo(112000, 0.0001));
      expect(summary.absolutePnl, closeTo(32000, 0.0001));
    });

    test('switch-out followed by switch-in stays cost neutral per scheme', () {
      final summary = calculator.calculate(
        transactions: <FundTransaction>[
          txn(
            id: 'P1',
            date: DateTime(2026, 1, 1),
            kind: TransactionKind.purchase,
            amount: 50000,
            units: 500,
            nav: 100,
          ),
          txn(
            id: 'SW1',
            date: DateTime(2026, 3, 1),
            kind: TransactionKind.switchOut,
            amount: 50000,
            units: 500,
            nav: 100,
          ),
          txn(
            id: 'SW2',
            date: DateTime(2026, 3, 1),
            kind: TransactionKind.switchIn,
            amount: 50000,
            units: 250,
            nav: 200,
            schemeCode: 120503,
            schemeName: 'HDFC Balanced Advantage Fund',
          ),
        ],
        navByKey: <String, NavQuote>{
          PortfolioCalculator.schemeKeyForCode(120503): quote(120503, 220),
        },
      );

      expect(summary.holdings, hasLength(1));
      expect(summary.closedSchemes, 1);
      expect(summary.holdings.single.schemeCode, 120503);
      expect(summary.totalInvested, 50000);
      expect(summary.currentValue, 55000);
    });

    test('falls back to average NAV when no live quote is available', () {
      final summary = calculator.calculate(
        transactions: <FundTransaction>[
          txn(
            id: 'T1',
            date: DateTime(2026, 1, 10),
            kind: TransactionKind.purchase,
            amount: 10000,
            units: 100,
            nav: 100,
          ),
        ],
      );

      expect(summary.holdings.single.navAvailable, isFalse);
      expect(summary.currentValue, 10000);
      expect(summary.absolutePnl, 0);
      expect(summary.returnPercent, 0);
      expect(summary.hasLiveNav, isFalse);
    });

    test('returns an empty summary for no transactions', () {
      final summary = calculator.calculate(transactions: const <FundTransaction>[]);
      expect(summary.isEmpty, isTrue);
      expect(summary.totalInvested, 0);
      expect(summary.returnPercent, 0);
    });

    test('ignores zero-unit and dividend style rows', () {
      final summary = calculator.calculate(
        transactions: <FundTransaction>[
          txn(
            id: 'D1',
            date: DateTime(2026, 1, 10),
            kind: TransactionKind.other,
            amount: 500,
            units: 0,
          ),
        ],
      );
      expect(summary.isEmpty, isTrue);
    });
  });
}
