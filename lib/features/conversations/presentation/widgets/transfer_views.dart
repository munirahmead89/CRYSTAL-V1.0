import 'package:flutter/material.dart';

import '../../../../core/media/transfer_progress.dart';
import '../../../../core/media/transfer_tracker.dart';
import '../../../../shared/widgets/smooth_progress.dart';

/// A single transfer line: name, determinate bar, percentage, size, speed and
/// a time remaining — the same information a WhatsApp upload/download row
/// shows.
///
/// The ETA is only rendered once there is enough signal to be honest about it.
/// Before that it reads "calculating", because a countdown derived from one
/// noisy sample is worse than admitting it does not know yet.
class TransferRow extends StatelessWidget {
  const TransferRow({
    super.key,
    required this.transfer,
    this.onCancel,
    this.dense = false,
  });

  final ActiveTransfer transfer;
  final VoidCallback? onCancel;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = transfer.progress;
    final isUpload = transfer.direction == TransferDirection.upload;

    final (statusText, statusColor) = switch (p) {
      _ when p.failed => ('Failed', theme.colorScheme.error),
      _ when p.done => (
        p.fromCache ? 'Ready (cached)' : (isUpload ? 'Sent' : 'Saved'),
        theme.colorScheme.primary,
      ),
      _ => (p.directionLabel, theme.colorScheme.onSurfaceVariant),
    };

    final speed = p.speedLabel;
    final eta = p.etaLabel;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 6 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUpload ? Icons.upload_file : Icons.downloading,
                size: dense ? 16 : 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  transfer.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (dense
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (p.isActive)
                Text(
                  p.percentLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Indeterminate when the total size is unknown, rather than a
              // 0% bar that looks stuck.
              Expanded(
                child: SmoothProgressBar(
                  value: p.done ? 1.0 : p.fraction,
                  height: dense ? 4 : 6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                p.transferredLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                statusText,
                style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
              ),
              if (speed != null) ...[
                _dot(theme),
                Text(
                  speed,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (eta != null) ...[
                _dot(theme),
                Text(
                  eta,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (p.isActive && speed == null) ...[
                _dot(theme),
                Text(
                  'calculating…',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              if (onCancel != null && p.isActive)
                InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(
                      'Cancel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text(
      '•',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Bottom sheet listing every upload and download this device is running.
///
/// The single answer to "what is my phone sending and receiving right now",
/// reachable from the chats list and from the chat itself.
class TransfersSheet extends StatelessWidget {
  const TransfersSheet({super.key, required this.tracker});

  final TransferTracker tracker;

  static Future<void> show(BuildContext context, TransferTracker tracker) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TransfersSheet(tracker: tracker),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) {
        final transfers = tracker.transfers;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Transfers',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (tracker.hasActive)
                        Text(
                          '${tracker.activeCount} active',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                if (transfers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.swap_vert_circle_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text('No transfers running'),
                        const SizedBox(height: 4),
                        Text(
                          'Photos, videos and files you send or receive '
                          'appear here.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: transfers.length,
                      itemBuilder: (context, index) {
                        final t = transfers[index];
                        return Column(
                          children: [
                            TransferRow(
                              transfer: t,
                              onCancel: () => tracker.cancel(t.id),
                            ),
                            if (index < transfers.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      },
                    ),
                  ),
                if (transfers.isNotEmpty && !tracker.hasActive)
                  TextButton(
                    onPressed: () {
                      tracker.clearFinished();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact pill that appears above the composer while transfers are running,
/// mirroring the persistent upload indicator WhatsApp shows.
class ActiveTransfersPill extends StatelessWidget {
  const ActiveTransfersPill({super.key, required this.tracker});

  final TransferTracker tracker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) {
        final active = tracker.active;
        if (active.isEmpty) return const SizedBox.shrink();
        final newest = active.first;
        final p = newest.progress;

        return Material(
          color: theme.colorScheme.secondaryContainer,
          child: InkWell(
            onTap: () => TransfersSheet.show(context, tracker),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    newest.direction == TransferDirection.upload
                        ? Icons.upload_file
                        : Icons.downloading,
                    size: 16,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.directionLabel} ${p.percentLabel}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _subtitle(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active.length > 1)
                    Text(
                      '+${active.length - 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _subtitle(TransferProgress p) {
    final eta = p.etaLabel;
    final speed = p.speedLabel;
    if (p.sizeLabel.isEmpty) return '';
    final parts = [p.sizeLabel, if (speed != null) speed, if (eta != null) eta];
    return parts.join(' • ');
  }
}
