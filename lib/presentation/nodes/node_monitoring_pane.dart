import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/nodes/domain/pve_node_metrics.dart';
import '../widgets/inventory_widgets.dart';
import 'node_monitoring_state.dart';

/// Node metrics are independent sections so a denied or failed endpoint never
/// hides the successful sections, or the last successfully collected values.
class NodeMonitoringPane extends StatelessWidget {
  const NodeMonitoringPane({
    super.key,
    required this.state,
    this.onTimeframeChanged,
    this.onRefresh,
  });

  final NodeMonitoringState state;
  final ValueChanged<PveNodeTimeframe>? onTimeframeChanged;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isStale) ...[
          Container(
            key: const ValueKey('node-monitoring-stale'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Text(
              '数据已过期，显示上次成功采集的结果。',
              style: inventoryText(12, color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _MonitoringSection(
          title: '资源概览',
          updatedAt: state.snapshotUpdatedAt,
          isLoading: state.isLoadingSnapshot,
          error: state.snapshotError,
          hasData: state.snapshot != null,
          onRefresh: onRefresh,
          child: state.snapshot == null
              ? _EmptyMetrics(
                  message: state.isLoadingSnapshot ? '正在读取节点状态…' : '暂无节点状态数据',
                )
              : _SnapshotMetrics(
                  snapshot: state.snapshot!,
                  points: state.points,
                ),
        ),
        const SizedBox(height: 18),
        _MonitoringSection(
          title: '历史趋势',
          updatedAt: state.historyUpdatedAt,
          isLoading: state.isLoadingHistory,
          error: state.historyError,
          hasData: state.points.isNotEmpty,
          onRefresh: onRefresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final timeframe in PveNodeTimeframe.values)
                    ChoiceChip(
                      key: ValueKey('monitoring-timeframe-${timeframe.name}'),
                      label: Text(_timeframeLabel(timeframe)),
                      selected: state.timeframe == timeframe,
                      showCheckmark: false,
                      onSelected: onTimeframeChanged == null
                          ? null
                          : (_) => onTimeframeChanged!(timeframe),
                      labelStyle: inventoryText(
                        12,
                        color: state.timeframe == timeframe
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'PVE 汇总采样 · 缺失数据以断线显示',
                style: inventoryText(11, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              if (state.points.isEmpty)
                _EmptyMetrics(
                  message: state.isLoadingHistory ? '正在读取历史采样…' : '此时间范围暂无历史数据',
                )
              else ...[
                _TrendChart(
                  title: 'CPU',
                  points: state.points,
                  maxValue: 100,
                  valueLabel: _percentValue,
                  series: [
                    _MetricSeries(
                      '使用率',
                      colors.primary,
                      (p) => _percentage(p.cpuUsage),
                    ),
                    _MetricSeries(
                      'I/O 等待',
                      colors.secondary,
                      (p) => _percentage(p.ioWait),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _TrendChart(
                  title: '内存',
                  points: state.points,
                  maxValue: 100,
                  valueLabel: _percentValue,
                  series: [
                    _MetricSeries(
                      '使用率',
                      colors.secondary,
                      (p) => _ratio(p.memoryUsedBytes, p.memoryTotalBytes),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _TrendChart(
                  title: '网络',
                  points: state.points,
                  valueLabel: _rateValue,
                  series: [
                    _MetricSeries(
                      '接收',
                      colors.primary,
                      (p) => _valid(p.netInBytesPerSecond),
                    ),
                    _MetricSeries(
                      '发送',
                      colors.secondary,
                      (p) => _valid(p.netOutBytesPerSecond),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _TrendChart(
                  title: '根分区',
                  points: state.points,
                  maxValue: 100,
                  valueLabel: _percentValue,
                  series: [
                    _MetricSeries(
                      '使用率',
                      colors.primary,
                      (p) => _ratio(p.rootfsUsedBytes, p.rootfsTotalBytes),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _MonitoringSection(
          title: '节点存储',
          updatedAt: state.storageUpdatedAt,
          isLoading: state.isLoadingStorage,
          error: state.storageError,
          hasData: state.storages.isNotEmpty,
          onRefresh: onRefresh,
          child: state.storages.isEmpty
              ? _EmptyMetrics(
                  message: state.isLoadingStorage
                      ? '正在读取存储…'
                      : '暂无可见存储，需 Datastore.Audit 权限',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < state.storages.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(height: 14),
                        Divider(color: colors.outlineVariant),
                        const SizedBox(height: 14),
                      ],
                      _StorageMetrics(storage: state.storages[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MonitoringSection extends StatelessWidget {
  const _MonitoringSection({
    required this.title,
    required this.child,
    required this.isLoading,
    required this.hasData,
    this.updatedAt,
    this.error,
    this.onRefresh,
  });

  final String title;
  final Widget child;
  final DateTime? updatedAt;
  final String? error;
  final bool isLoading;
  final bool hasData;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _MonitoringSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: inventoryText(
                    14,
                    color: colors.onSurface,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '刷新$title',
                onPressed: isLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          Text(
            updatedAt == null ? '尚未更新' : '更新于 ${_dateTimeLabel(updatedAt!)}',
            style: inventoryText(11, color: colors.onSurfaceVariant),
          ),
          if (isLoading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              hasData ? '$error\n保留上次成功采集的数据。' : error!,
              style: inventoryText(12, color: colors.error),
            ),
            if (onRefresh != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: isLoading ? null : onRefresh,
                  child: const Text('重试'),
                ),
              ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MonitoringSurface extends StatelessWidget {
  const _MonitoringSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _EmptyMetrics extends StatelessWidget {
  const _EmptyMetrics({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(
      message,
      style: inventoryText(
        12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _SnapshotMetrics extends StatelessWidget {
  const _SnapshotMetrics({required this.snapshot, required this.points});

  final PveNodeMetricsSnapshot snapshot;
  final List<PveNodeRrdPoint> points;

  @override
  Widget build(BuildContext context) {
    PveNodeRrdPoint? networkSample;
    for (final point in points) {
      if ((_valid(point.netInBytesPerSecond) != null ||
              _valid(point.netOutBytesPerSecond) != null) &&
          (networkSample == null || point.time.isAfter(networkSample.time))) {
        networkSample = point;
      }
    }
    final colors = Theme.of(context).colorScheme;
    final cards = [
      _MetricCard(
        label: 'CPU',
        value: _percentValue(_percentage(snapshot.cpuUsage)),
        detail:
            '${snapshot.cpuCount == null ? '核心数未知' : '${snapshot.cpuCount} 核'} · I/O 等待 ${_percentValue(_percentage(snapshot.ioWait))}',
        progress: snapshot.cpuUsage,
        color: colors.primary,
      ),
      _MetricCard(
        label: '内存',
        value: _bytesValue(snapshot.memoryUsedBytes),
        detail:
            '共 ${_bytesValue(snapshot.memoryTotalBytes)}\n可用 ${_bytesValue(snapshot.memoryAvailableBytes)}',
        progress: _fraction(
          snapshot.memoryUsedBytes,
          snapshot.memoryTotalBytes,
        ),
        color: colors.secondary,
      ),
      _MetricCard(
        label: '根分区',
        value: _bytesValue(snapshot.rootfsUsedBytes),
        detail:
            '共 ${_bytesValue(snapshot.rootfsTotalBytes)}\n可用 ${_bytesValue(snapshot.rootfsAvailableBytes)}',
        progress: _fraction(
          snapshot.rootfsUsedBytes,
          snapshot.rootfsTotalBytes,
        ),
        color: colors.primary,
      ),
      _MetricCard(
        label: '网络 · 最近采样',
        value: '↓ ${_rateValue(networkSample?.netInBytesPerSecond)}',
        detail:
            '↑ ${_rateValue(networkSample?.netOutBytesPerSecond)}\n${networkSample == null ? '暂无网络采样' : _dateTimeLabel(networkSample.time)}',
        color: colors.secondary,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 250 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.4
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _MetricDetail(
          label: '负载 1 / 5 / 15 分钟',
          value: snapshot.loadAverage.isEmpty
              ? '—'
              : snapshot.loadAverage
                    .map(
                      (value) => value.isFinite && value >= 0
                          ? value.toStringAsFixed(2)
                          : '—',
                    )
                    .join(' / '),
        ),
        const SizedBox(height: 9),
        _MetricDetail(
          label: 'Swap 已用 / 总量',
          value:
              '${_bytesValue(snapshot.swapUsedBytes)} / ${_bytesValue(snapshot.swapTotalBytes)}',
        ),
        if (snapshot.cpuModel != null) ...[
          const SizedBox(height: 9),
          _MetricDetail(label: '处理器', value: snapshot.cpuModel!),
        ],
        if (snapshot.pveVersion != null) ...[
          const SizedBox(height: 9),
          _MetricDetail(label: 'PVE 版本', value: snapshot.pveVersion!),
        ],
        const SizedBox(height: 10),
        Text(
          '网络为所选时间范围的 PVE 汇总采样，非秒级实时速率。',
          style: inventoryText(11, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    this.progress,
  });
  final String label;
  final String value;
  final String detail;
  final Color color;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalized = _valid(progress) == null
        ? null
        : normalizedProgress(progress);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: inventoryText(11, color: colors.onSurfaceVariant)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: inventoryText(
                21,
                color: colors.onSurface,
                numeric: true,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            style: inventoryText(11, color: colors.onSurfaceVariant),
          ),
          if (normalized != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: normalized,
                minHeight: 4,
                color: color,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricDetail extends StatelessWidget {
  const _MetricDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: inventoryText(11, color: colors.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(
          value,
          style: inventoryText(
            12,
            color: colors.onSurface,
            weight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StorageMetrics extends StatelessWidget {
  const _StorageMetrics({required this.storage});
  final PveStorageStatus storage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fraction = _fraction(storage.usedBytes, storage.totalBytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          storage.id,
          style: inventoryText(
            13,
            color: colors.onSurface,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${storage.type} · ${_booleanLabel(storage.isActive, '可用', '不可用')} · ${_booleanLabel(storage.isEnabled, '已启用', '已禁用')}${storage.isShared == true ? ' · 共享' : ''}',
          style: inventoryText(
            11,
            color: storage.isActive == false
                ? colors.error
                : colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_bytesValue(storage.usedBytes)} / ${_bytesValue(storage.totalBytes)}',
          style: inventoryText(13, color: colors.onSurface, numeric: true),
        ),
        if (fraction != null) ...[
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 4,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ],
        const SizedBox(height: 7),
        Text(
          '可用 ${_bytesValue(storage.availableBytes)} · 使用率 ${_percentValue(fraction == null ? null : fraction * 100)}',
          style: inventoryText(11, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

typedef _MetricValue = double? Function(PveNodeRrdPoint point);
typedef _ValueLabel = String Function(double? value);

class _MetricSeries {
  const _MetricSeries(this.label, this.color, this.value);
  final String label;
  final Color color;
  final _MetricValue value;
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.title,
    required this.points,
    required this.series,
    required this.valueLabel,
    this.maxValue,
  });
  final String title;
  final List<PveNodeRrdPoint> points;
  final List<_MetricSeries> series;
  final _ValueLabel valueLabel;
  final double? maxValue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ordered = points.toList()..sort((a, b) => a.time.compareTo(b.time));
    final allValues = [
      for (final line in series)
        for (final point in ordered)
          if (line.value(point) != null) line.value(point)!,
    ];
    final peak = allValues.fold<double>(0, math.max);
    final ceiling = maxValue ?? (peak <= 0 ? 1.0 : peak * 1.1);
    final summaries = <String>[];
    for (final line in series) {
      final values = ordered.map(line.value).whereType<double>().toList();
      summaries.add(
        values.isEmpty
            ? '${line.label} 暂无数据'
            : '${line.label}：最近 ${valueLabel(values.last)}，峰值 ${valueLabel(values.reduce(math.max))}',
      );
    }
    final summary = summaries.join('；');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: inventoryText(
            13,
            color: colors.onSurface,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 12,
          runSpacing: 5,
          children: [
            for (final line in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: line.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    line.label,
                    style: inventoryText(11, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 9),
        if (allValues.isEmpty)
          const _EmptyMetrics(message: '此指标暂无历史数据')
        else
          Semantics(
            label: '$title 历史趋势。$summary。缺失采样以断线显示。',
            image: true,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    valueLabel(ceiling),
                    style: inventoryText(10, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 88,
                    child: CustomPaint(
                      key: ValueKey('monitoring-chart-$title'),
                      painter: _TrendPainter(
                        points: ordered,
                        series: series,
                        ceiling: ceiling,
                        gridColor: colors.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateTimeLabel(ordered.first.time),
                          style: inventoryText(
                            10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dateTimeLabel(ordered.last.time),
                          textAlign: TextAlign.right,
                          style: inventoryText(
                            10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (allValues.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            summary,
            style: inventoryText(11, color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.points,
    required this.series,
    required this.ceiling,
    required this.gridColor,
  });
  final List<PveNodeRrdPoint> points;
  final List<_MetricSeries> series;
  final double ceiling;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final firstTime = points.first.time.millisecondsSinceEpoch;
    final duration = points.last.time.millisecondsSinceEpoch - firstTime;
    final intervals = <int>[
      for (var i = 1; i < points.length; i++)
        if (points[i].time.isAfter(points[i - 1].time))
          points[i].time.difference(points[i - 1].time).inMilliseconds,
    ]..sort();
    // Explicit nulls break the path; missing rows also break it when their time
    // gap exceeds the normal sampling interval. Neither becomes a zero value.
    final normalInterval = intervals.isEmpty
        ? null
        : intervals[(intervals.length - 1) ~/ 2];
    for (final line in series) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      var connected = false;
      DateTime? previousTime;
      for (final point in points) {
        final value = line.value(point);
        if (value == null || !value.isFinite || value < 0) {
          connected = false;
          previousTime = point.time;
          continue;
        }
        final x = duration <= 0
            ? size.width / 2
            : (point.time.millisecondsSinceEpoch - firstTime) /
                  duration *
                  size.width;
        final y = size.height * (1 - (value / ceiling).clamp(0.0, 1.0));
        final hasGap =
            normalInterval != null &&
            previousTime != null &&
            point.time.difference(previousTime).inMilliseconds >
                normalInterval * 2;
        if (connected && !hasGap) {
          path.lineTo(x, y);
        } else {
          path.moveTo(x, y);
          canvas.drawCircle(Offset(x, y), 2, Paint()..color = line.color);
        }
        connected = true;
        previousTime = point.time;
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.series != series ||
      oldDelegate.ceiling != ceiling ||
      oldDelegate.gridColor != gridColor;
}

String _timeframeLabel(PveNodeTimeframe timeframe) => switch (timeframe) {
  PveNodeTimeframe.hour => '1 小时',
  PveNodeTimeframe.day => '24 小时',
  PveNodeTimeframe.week => '1 周',
  PveNodeTimeframe.month => '1 月',
  PveNodeTimeframe.year => '1 年',
};

double? _valid(double? value) =>
    value == null || !value.isFinite || value < 0 ? null : value;
double? _percentage(double? value) =>
    _valid(value) == null ? null : value!.clamp(0.0, 1.0) * 100;
double? _ratio(double? used, double? total) =>
    _valid(used) == null || _valid(total) == null || total! <= 0
    ? null
    : (used! / total).clamp(0.0, 1.0) * 100;
double? _fraction(int? used, int? total) =>
    used == null || used < 0 || total == null || total <= 0
    ? null
    : used / total;
String _percentValue(double? value) =>
    _valid(value) == null ? '—' : '${value!.toStringAsFixed(1)}%';
String _bytesValue(int? value) =>
    value == null || value < 0 ? '—' : _humanBytes(value.toDouble());
String _rateValue(double? value) =>
    _valid(value) == null ? '—' : '${_humanBytes(value!)}/s';

String _humanBytes(double value) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String _booleanLabel(bool? value, String yes, String no) => value == null
    ? '状态未知'
    : value
    ? yes
    : no;
String _dateTimeLabel(DateTime time) {
  final local = time.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} ${pad(local.hour)}:${pad(local.minute)}';
}
