import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/sync_result.dart';
import 'admin_providers.dart';

/// Admin trigger for the Gmail → CAMS statement pipeline plus a run history.
class AdminSyncScreen extends ConsumerStatefulWidget {
  const AdminSyncScreen({super.key});

  @override
  ConsumerState<AdminSyncScreen> createState() => _AdminSyncScreenState();
}

class _AdminSyncScreenState extends ConsumerState<AdminSyncScreen> {
  bool _running = false;
  SyncResult? _lastResult;
  String? _error;

  Future<void> _runSync() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final result = await ref.read(adminRepositoryProvider).triggerManualSync();
      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? 'Sync finished — ${result.transactionsCreated} new transaction(s)'
                : 'Sync finished with status: ${result.status}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AppException.describe(error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(adminSyncLogsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Statement pipeline',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'CAMS and KFintech emails are read from Gmail, parsed and '
                  'matched to client PANs. The scheduled job runs every day at '
                  '9:00 AM IST; a manual run is safe to repeat — duplicate rows '
                  'are skipped.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.cloud_download_outlined,
                              size: 19,
                              color: AppColors.goldSoft,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'CAMS & KFintech statement sync',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Daily at 9:00 AM  ·  Asia/Kolkata  ·  '
                                  'idempotent writes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'GMAIL QUERY',
                              style: TextStyle(
                                fontSize: 8.5,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              'CAMS: from:${AppConstants.camsSender} has:attachment '
                              '(filename:zip OR filename:csv) is:unread\n'
                              'KFintech: from:${AppConstants.kfintechSender} is:unread',
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                fontFamily: 'monospace',
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _running ? null : _runSync,
                        icon: _running
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync_rounded, size: 17),
                        label: Text(
                          _running ? 'Scanning inbox…' : 'Run manual sync now',
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.coralWash,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.coralWash),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.coralDeep,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      if (_lastResult != null) ...<Widget>[
                        const SizedBox(height: 14),
                        _ResultSummary(result: _lastResult!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AsyncValueView<List<SyncLogEntry>>(
                  asyncValue: logsAsync,
                  onRetry: () => ref.invalidate(adminSyncLogsProvider),
                  builder: (logs) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SectionHeader(
                          eyebrow: 'Audit',
                          title: 'Run history',
                          subtitle: logs.isEmpty
                              ? 'No runs recorded yet'
                              : 'Last ${logs.length} run${logs.length == 1 ? '' : 's'}, newest first',
                        ),
                        const SizedBox(height: 10),
                        if (logs.isEmpty)
                          const AppCard(
                            child: EmptyState(
                              icon: Icons.history_rounded,
                              title: 'No sync runs yet',
                              message:
                                  'Run a manual sync or wait for the scheduled '
                                  'job to write its first log entry.',
                            ),
                          )
                        else
                          for (final log in logs) ...<Widget>[
                            _LogTile(entry: log),
                            const SizedBox(height: 8),
                          ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.result});

  final SyncResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.isSuccess;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? AppColors.emeraldWash : AppColors.amberWash,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                ok
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 15,
                color: ok ? AppColors.emeraldDeep : AppColors.amber,
              ),
              const SizedBox(width: 6),
              Text(
                'Sync ${result.status}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ok ? AppColors.emeraldDeep : AppColors.amber,
                ),
              ),
              const Spacer(),
              Text(
                '${(result.durationMs / 1000).toStringAsFixed(1)}s',
                style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              _Count(label: 'Emails', value: result.messagesScanned),
              _Count(label: 'Attachments', value: result.attachmentsParsed),
              _Count(label: 'Folios', value: result.foliosMapped),
              _Count(label: 'Unmapped', value: result.unmappedRows),
              _Count(label: 'New rows', value: result.transactionsCreated),
              _Count(label: 'Duplicates', value: result.duplicatesSkipped),
            ],
          ),
          if (result.errors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final error in result.errors.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• $error',
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppColors.slate,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label ',
          style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final SyncLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ok = entry.isSuccess;
    final color = ok ? AppColors.emeraldDeep : AppColors.coralDeep;
    final wash = ok ? AppColors.emeraldWash : AppColors.coralWash;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusBadge(
                label: entry.status.isEmpty ? 'UNKNOWN' : entry.status.toUpperCase(),
                color: color,
                wash: wash,
                dense: true,
              ),
              const SizedBox(width: 8),
              Text(
                entry.trigger.isEmpty ? 'sync' : entry.trigger,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate,
                ),
              ),
              const Spacer(),
              Text(
                Formatters.timestamp(entry.startedAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.slateLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.messagesScanned} emails  ·  ${entry.foliosMapped} folios  ·  '
            '${entry.transactionsCreated} new  ·  '
            '${entry.duplicatesSkipped} duplicates'
            '${entry.durationMs > 0 ? '  ·  ${(entry.durationMs / 1000).toStringAsFixed(1)}s' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.slate),
          ),
          if (entry.errorMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              entry.errorMessage,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.coralDeep,
                height: 1.4,
              ),
            ),
          ],
          if (entry.errors.isNotEmpty && entry.errorMessage.isEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              entry.errors.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.coralDeep,
                height: 1.4,
              ),
            ),
          ],
          if (entry.actor.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Triggered by ${entry.actor}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.slateLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
