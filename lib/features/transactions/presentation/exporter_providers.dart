import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/report_exporter.dart';

/// Kept behind a provider so the exporter can be substituted in tests.
final reportExporterProvider = Provider<ReportExporter>(
  (ref) => const ReportExporter(),
);
