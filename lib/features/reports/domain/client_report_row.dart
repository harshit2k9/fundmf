/// One client row in the admin directory export.
///
/// Kept deliberately flat so the CSV/PDF builders do not depend on the admin
/// presentation layer.
class ClientReportRow {
  const ClientReportRow({
    required this.clientId,
    required this.name,
    required this.email,
    required this.pan,
    required this.phone,
    required this.status,
    required this.schemes,
    required this.invested,
    required this.currentValue,
    required this.pnl,
  });

  final String clientId;
  final String name;
  final String email;
  final String pan;
  final String phone;
  final String status;
  final int schemes;
  final double invested;
  final double currentValue;
  final double pnl;

  double get returnPercent => invested > 0 ? (pnl / invested) * 100 : 0;
}
