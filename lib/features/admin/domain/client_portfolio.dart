import '../../portfolio/domain/portfolio_summary.dart';
import '../../reports/domain/client_report_row.dart';
import '../../users/domain/user_profile.dart';

/// A client directory row joined with their live portfolio valuation.
class AdminClientPortfolio {
  const AdminClientPortfolio({required this.client, required this.summary});

  final UserProfile client;
  final PortfolioSummary summary;

  bool get hasPortfolio => !summary.isEmpty;

  ClientReportRow toReportRow() => ClientReportRow(
        clientId: client.clientId.isEmpty ? '—' : client.clientId,
        name: client.fullName,
        email: client.email,
        pan: client.pan,
        phone: client.phone,
        status: client.statusLabel,
        schemes: summary.holdings.length,
        invested: summary.totalInvested,
        currentValue: summary.currentValue,
        pnl: summary.absolutePnl,
      );
}

/// Aggregate book of business shown on the admin overview.
class AdminTotals {
  const AdminTotals({
    required this.clients,
    required this.active,
    required this.pending,
    required this.unclaimed,
    required this.aum,
    required this.invested,
    required this.pnl,
    required this.schemes,
    required this.fundedClients,
  });

  final int clients;
  final int active;
  final int pending;
  final int unclaimed;
  final double aum;
  final double invested;
  final double pnl;
  final int schemes;
  final int fundedClients;

  double get returnPercent => invested > 0 ? (pnl / invested) * 100 : 0;

  static const AdminTotals empty = AdminTotals(
    clients: 0,
    active: 0,
    pending: 0,
    unclaimed: 0,
    aum: 0,
    invested: 0,
    pnl: 0,
    schemes: 0,
    fundedClients: 0,
  );

  factory AdminTotals.from(List<AdminClientPortfolio> rows) {
    var active = 0;
    var pending = 0;
    var unclaimed = 0;
    var aum = 0.0;
    var invested = 0.0;
    var pnl = 0.0;
    var schemes = 0;
    var funded = 0;

    for (final row in rows) {
      switch (row.client.status) {
        case AccountStatus.active:
          active++;
        case AccountStatus.pendingApproval:
          pending++;
        case AccountStatus.unclaimed:
          unclaimed++;
      }
      if (row.hasPortfolio) {
        funded++;
        aum += row.summary.currentValue;
        invested += row.summary.totalInvested;
        pnl += row.summary.absolutePnl;
        schemes += row.summary.holdings.length;
      }
    }

    return AdminTotals(
      clients: rows.length,
      active: active,
      pending: pending,
      unclaimed: unclaimed,
      aum: aum,
      invested: invested,
      pnl: pnl,
      schemes: schemes,
      fundedClients: funded,
    );
  }
}
