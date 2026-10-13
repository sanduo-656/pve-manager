import 'package:flutter/material.dart';

import 'pve_icon.dart';

const inventoryInk = Color(0xFF172239);
const inventoryMuted = Color(0xFF6F7C92);
const inventoryBorder = Color(0xFFE5E9F1);

TextStyle inventoryText(
  double size, {
  Color color = inventoryInk,
  FontWeight weight = FontWeight.w400,
  double? height,
  bool numeric = false,
}) => TextStyle(
  fontFamily: numeric ? 'Inter' : 'Noto Sans SC',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height:
      height ??
      (size == 11
          ? 16 / 11
          : size == 12
          ? 17 / 12
          : size == 13
          ? 19 / 13
          : size == 14
          ? 20 / 14
          : size == 21
          ? 30 / 21
          : 36 / 25),
  letterSpacing: 0,
);

class InventoryConnectionLine extends StatelessWidget {
  const InventoryConnectionLine({
    super.key,
    required this.menuKey,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.online,
    this.lastUpdatedAt,
  });
  final Key menuKey;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final bool online;
  final DateTime? lastUpdatedAt;
  String get _updatedLabel {
    if (lastUpdatedAt == null) return '尚未更新';
    final minutes = DateTime.now().difference(lastUpdatedAt!).inMinutes;
    if (minutes < 1) return '刚刚更新';
    if (minutes < 60) return '$minutes 分钟前更新';
    return '${minutes ~/ 60} 小时前更新';
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 19,
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? const Color(0xFF15936A) : const Color(0xFF9CA6BA),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: InventoryFilterMenu(
              key: menuKey,
              label: '切换连接',
              value: value,
              items: items,
              onChanged: onChanged,
              height: 19,
              textSize: 13,
              color: const Color(0xFF34415B),
              textWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_updatedLabel, style: inventoryText(11)),
      ],
    ),
  );
}

class InventoryOverview extends StatelessWidget {
  const InventoryOverview({
    super.key,
    required this.title,
    required this.total,
    required this.counts,
    this.unit = '台',
  });
  final String title;
  final int total;
  final Map<String, int> counts;
  final String unit;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 106),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF3448C8),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: inventoryText(12, color: const Color(0xFFCDD5FF)),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: inventoryText(
                      36,
                      numeric: true,
                      weight: FontWeight.w600,
                      color: Colors.white,
                      height: 44 / 36,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: inventoryText(12, color: const Color(0xFFCDD5FF)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < counts.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            counts.keys.elementAt(i) == '运行中' ||
                                counts.keys.elementAt(i) == '在线'
                            ? const Color(0xFF8FE3BE)
                            : const Color(0xFFBAC4FA),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        counts.keys.elementAt(i),
                        style: inventoryText(
                          12,
                          color: const Color(0xFFD9DFFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${counts.values.elementAt(i)}',
                      textAlign: TextAlign.right,
                      style: inventoryText(
                        17,
                        numeric: true,
                        weight: FontWeight.w600,
                        color: Colors.white,
                        height: 21 / 17,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class InventoryFilterMenu extends StatelessWidget {
  const InventoryFilterMenu({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon = PveIconName.chevronDown,
    this.height = 36,
    this.textSize = 12,
    this.color = const Color(0xFF64718A),
    this.textWeight = FontWeight.w400,
  });
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final PveIconName icon;
  final double height;
  final double textSize;
  final Color color;
  final FontWeight textWeight;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: label,
    initialValue: value,
    onSelected: onChanged,
    padding: EdgeInsets.zero,
    itemBuilder: (_) => [
      for (final item in items.entries)
        PopupMenuItem(
          value: item.key,
          child: Text(item.value, style: inventoryText(13)),
        ),
    ],
    child: SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == PveIconName.slidersHorizontal) ...[
            PveIcon(icon, size: 15, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              items[value] ?? '全部连接',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: inventoryText(textSize, color: color, weight: textWeight),
            ),
          ),
          if (icon != PveIconName.slidersHorizontal) ...[
            const SizedBox(width: 8),
            PveIcon(icon, size: 15, color: const Color(0xFF64718A)),
          ],
        ],
      ),
    ),
  );
}

class InventoryTypeButton extends StatelessWidget {
  const InventoryTypeButton({
    super.key,
    required this.label,
    required this.width,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final double width;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? const Color(0xFFE8ECFF) : Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: width,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: inventoryText(
                12,
                color: selected
                    ? const Color(0xFF3448C8)
                    : const Color(0xFF64718A),
                weight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class InventoryIcon extends StatelessWidget {
  const InventoryIcon({
    super.key,
    required this.icon,
    this.secondary = false,
    this.size = 38,
    this.detail = false,
  });
  final PveIconName icon;
  final bool secondary;
  final double size;
  final bool detail;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: secondary
          ? const Color(0xFFE8F5F2)
          : detail
          ? const Color(0xFFE9EDFF)
          : const Color(0xFFEDF0FF),
      borderRadius: BorderRadius.circular(detail ? 14 : 10),
    ),
    child: Center(
      child: PveIcon(
        icon,
        size: detail ? 24 : 19,
        color: secondary
            ? const Color(0xFF268673)
            : detail
            ? const Color(0xFF3448C8)
            : const Color(0xFF4959CA),
      ),
    ),
  );
}

class InventoryUsage extends StatelessWidget {
  const InventoryUsage({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.secondary = false,
  });
  final String label;
  final String value;
  final double? progress;
  final bool secondary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: inventoryText(11))),
          Text(
            value,
            style: inventoryText(
              11,
              color: const Color(0xFF52607A),
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      InventoryTrack(progress: progress, secondary: secondary),
    ],
  );
}

class InventoryTrack extends StatelessWidget {
  const InventoryTrack({
    super.key,
    required this.progress,
    this.secondary = false,
    this.detail = false,
  });
  final double? progress;
  final bool secondary;
  final bool detail;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(detail ? 3 : 2),
    child: SizedBox(
      height: detail ? 5 : 4,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFFEDF0F6))),
            SizedBox(
              width: constraints.maxWidth * (normalizedProgress(progress) ?? 0),
              height: detail ? 5 : 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: secondary
                      ? (detail
                            ? const Color(0xFF46A392)
                            : const Color(0xFF49A696))
                      : (detail
                            ? const Color(0xFF6778D5)
                            : const Color(0xFF6878D9)),
                  borderRadius: BorderRadius.circular(detail ? 3 : 2),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class InventorySurface extends StatelessWidget {
  const InventorySurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 14,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: inventoryBorder),
    ),
    child: child,
  );
}

class InventoryMetric extends StatelessWidget {
  const InventoryMetric({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    required this.progress,
    this.secondary = false,
  });
  final String label;
  final String value;
  final String description;
  final double? progress;
  final bool secondary;
  @override
  Widget build(BuildContext context) => InventorySurface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: inventoryText(12, color: const Color(0xFF68758C))),
        const SizedBox(height: 9),
        SizedBox(
          height: 30,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: inventoryText(
                25,
                numeric: true,
                height: 30 / 25,
                color: const Color(0xFF263450),
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: inventoryText(11),
        ),
        const SizedBox(height: 9),
        InventoryTrack(progress: progress, secondary: secondary, detail: true),
      ],
    ),
  );
}

class InventoryMetadataRow extends StatelessWidget {
  const InventoryMetadataRow({
    super.key,
    required this.label,
    required this.value,
  });
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: inventoryText(12)),
      const SizedBox(width: 20),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: inventoryText(
            12,
            color: const Color(0xFF34415A),
            weight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class InventoryDetailHeading extends StatelessWidget {
  const InventoryDetailHeading({
    super.key,
    required this.title,
    required this.backLabel,
    this.onBack,
  });
  final String title;
  final String backLabel;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        if (onBack != null) ...[
          Tooltip(
            message: backLabel,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack,
                child: const SizedBox(
                  width: 32,
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PveIcon(
                      PveIconName.arrowLeft,
                      size: 21,
                      color: Color(0xFF34415A),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(title, style: inventoryText(25, weight: FontWeight.w700)),
      ],
    ),
  );
}

class InventoryButtonContent extends StatelessWidget {
  const InventoryButtonContent({
    super.key,
    required this.icon,
    required this.label,
  });
  final Widget icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 7),
      Flexible(child: Text(label)),
    ],
  );
}

ButtonStyle inventoryPrimaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: const Color(0xFF3448C8),
  foregroundColor: Colors.white,
  disabledBackgroundColor: const Color(0xFFE7ECF5),
  disabledForegroundColor: const Color(0xFF8A94A8),
  minimumSize: const Size(0, 52),
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: inventoryText(14, weight: FontWeight.w600),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);
ButtonStyle inventorySecondaryButtonStyle({bool danger = false}) =>
    OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: danger
          ? const Color(0xFFB42318)
          : const Color(0xFF56647D),
      disabledForegroundColor: const Color(0xFF9CA6BA),
      minimumSize: const Size(0, 48),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: const BorderSide(color: Color(0xFFDCE2EE)),
      textStyle: inventoryText(13, weight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

double? normalizedProgress(double? value) =>
    value == null || !value.isFinite || value < 0
    ? null
    : value.clamp(0.0, 1.0);
double? memoryFraction(int? used, int? total) =>
    used == null || used < 0 || total == null || total <= 0
    ? null
    : used / total;
String formatPercent(double? value) {
  final normalized = normalizedProgress(value);
  return normalized == null ? '—' : '${(normalized * 100).toStringAsFixed(0)}%';
}

String formatMemory(int? used, int? total) {
  if (memoryFraction(used, total) == null) return '—';
  return '${formatBytes(used!)} / ${formatBytes(total!)}';
}

String formatBytes(int bytes) {
  const gib = 1024 * 1024 * 1024;
  const mib = 1024 * 1024;
  if (bytes >= gib) return '${(bytes / gib).toStringAsFixed(1)} GiB';
  if (bytes >= mib) return '${(bytes / mib).toStringAsFixed(0)} MiB';
  return '$bytes B';
}

String formatMemoryCapacity(int bytes) {
  const gib = 1024 * 1024 * 1024;
  if (bytes > 0 && bytes % gib == 0) return '${bytes ~/ gib} GiB';
  return formatBytes(bytes);
}
