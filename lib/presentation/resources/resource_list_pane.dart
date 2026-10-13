import 'package:flutter/material.dart';

import '../view_models.dart';
import '../widgets/feedback_views.dart';
import '../widgets/status_badge.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/pve_icon.dart';

export '../widgets/inventory_widgets.dart'
    show formatPercent, formatMemory, formatBytes;

class ResourceListPane extends StatefulWidget {
  const ResourceListPane({
    super.key,
    required this.resources,
    required this.connections,
    required this.filter,
    required this.onFilterChanged,
    required this.onResourceSelected,
    this.selectedResourceId,
    this.state = const PaneStateViewModel(),
    this.partialErrors = const [],
    this.onStateAction,
    this.onRetryPartialErrors,
    this.onRefresh,
    this.lastUpdatedAt,
    this.connectionOnline,
  });

  final List<ResourceViewModel> resources;
  final List<ConnectionOptionViewModel> connections;
  final ResourceFilterViewModel filter;
  final ValueChanged<ResourceFilterViewModel> onFilterChanged;
  final ValueChanged<ResourceViewModel> onResourceSelected;
  final String? selectedResourceId;
  final PaneStateViewModel state;
  final List<ScopedErrorViewModel> partialErrors;
  final UiAction? onStateAction;
  final UiAction? onRetryPartialErrors;
  final UiAction? onRefresh;
  final DateTime? lastUpdatedAt;
  final bool? connectionOnline;

  @override
  State<ResourceListPane> createState() => _ResourceListPaneState();
}

class _ResourceListPaneState extends State<ResourceListPane> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filter.query);
  }

  @override
  void didUpdateWidget(ResourceListPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.query != widget.filter.query &&
        _searchController.text != widget.filter.query) {
      _searchController.value = TextEditingValue(
        text: widget.filter.query,
        selection: TextSelection.collapsed(offset: widget.filter.query.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ResourceViewModel> get _visibleResources {
    final query = widget.filter.query.trim().toLowerCase();
    return widget.resources
        .where((resource) {
          if (widget.filter.kind != null &&
              resource.kind != widget.filter.kind) {
            return false;
          }
          if (widget.filter.status != null &&
              resource.status != widget.filter.status) {
            return false;
          }
          if (widget.filter.connectionId != null &&
              resource.connectionId != widget.filter.connectionId) {
            return false;
          }
          if (query.isEmpty) return true;
          return resource.name.toLowerCase().contains(query) ||
              resource.guestId.toLowerCase().contains(query) ||
              resource.nodeName.toLowerCase().contains(query) ||
              resource.connectionName.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleResources;
    final scoped = widget.resources
        .where(
          (r) =>
              widget.filter.connectionId == null ||
              r.connectionId == widget.filter.connectionId,
        )
        .toList();
    final connectionValue =
        widget.filter.connectionId ??
        (widget.connections.length == 1 ? widget.connections.first.id : 'all');
    final online =
        widget.connectionOnline ??
        (widget.state.showsContent &&
            widget.connections.isNotEmpty &&
            !widget.partialErrors.any(
              (e) =>
                  connectionValue == 'all' || e.connectionId == connectionValue,
            ));
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh?.call(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InventoryConnectionLine(
                    menuKey: ValueKey(
                      'connection-${widget.filter.connectionId ?? 'all'}',
                    ),
                    value: connectionValue,
                    items: {
                      'all': '全部连接',
                      for (final c in widget.connections) c.id: c.name,
                    },
                    onChanged: (v) => widget.onFilterChanged(
                      v == 'all'
                          ? widget.filter.copyWith(clearConnection: true)
                          : widget.filter.copyWith(connectionId: v),
                    ),
                    online: online,
                    lastUpdatedAt: widget.lastUpdatedAt,
                  ),
                  const SizedBox(height: 22),
                  InventoryOverview(
                    title: '全部资源',
                    total: scoped.length,
                    counts: {
                      '运行中': scoped.where((r) => r.isRunning).length,
                      '已关机': scoped
                          .where((r) => r.status == ResourceStatus.stopped)
                          .length,
                      if (scoped.any((r) => r.status == ResourceStatus.paused))
                        '已暂停': scoped
                            .where((r) => r.status == ResourceStatus.paused)
                            .length,
                      if (scoped.any((r) => r.status == ResourceStatus.unknown))
                        '未知': scoped
                            .where((r) => r.status == ResourceStatus.unknown)
                            .length,
                    },
                  ),
                  const SizedBox(height: 22),
                  SearchBar(
                    controller: _searchController,
                    constraints: const BoxConstraints(
                      minHeight: 46,
                      maxHeight: 46,
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 10),
                    ),
                    textStyle: WidgetStatePropertyAll(inventoryText(13)),
                    hintStyle: WidgetStatePropertyAll(inventoryText(13)),
                    hintText: '搜索名称或 VMID',
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: PveIcon(
                        PveIconName.search,
                        size: 18,
                        color: Color(0xFF8A94A8),
                      ),
                    ),
                    trailing: [
                      if (widget.filter.query.isNotEmpty)
                        IconButton(
                          tooltip: '清除搜索',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 24,
                            height: 32,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            widget.onFilterChanged(
                              widget.filter.copyWith(query: ''),
                            );
                          },
                          icon: const PveIcon(
                            PveIconName.x,
                            size: 16,
                            color: inventoryMuted,
                          ),
                        ),
                    ],
                    onChanged: (v) => widget.onFilterChanged(
                      widget.filter.copyWith(query: v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    key: ValueKey('kind-${widget.filter.kind?.name ?? 'all'}'),
                    children: [
                      InventoryTypeButton(
                        label: '全部',
                        width: 57,
                        selected: widget.filter.kind == null,
                        onPressed: () => widget.onFilterChanged(
                          widget.filter.copyWith(clearKind: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InventoryTypeButton(
                        label: '虚拟机',
                        width: 69,
                        selected: widget.filter.kind == ResourceKind.qemu,
                        onPressed: () => widget.onFilterChanged(
                          widget.filter.copyWith(kind: ResourceKind.qemu),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InventoryTypeButton(
                        label: '容器',
                        width: 57,
                        selected: widget.filter.kind == ResourceKind.lxc,
                        onPressed: () => widget.onFilterChanged(
                          widget.filter.copyWith(kind: ResourceKind.lxc),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: InventoryFilterMenu(
                            key: ValueKey(
                              'status-${widget.filter.status?.name ?? 'all'}',
                            ),
                            label: '状态筛选',
                            value: widget.filter.status?.name ?? 'all',
                            icon: PveIconName.slidersHorizontal,
                            items: const {
                              'all': '状态',
                              'running': '运行中',
                              'stopped': '已关机',
                              'paused': '已暂停',
                              'unknown': '未知',
                            },
                            onChanged: (v) => widget.onFilterChanged(
                              v == 'all'
                                  ? widget.filter.copyWith(clearStatus: true)
                                  : widget.filter.copyWith(
                                      status: ResourceStatus.values.byName(v),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PartialErrorBanner(
              errors: widget.partialErrors,
              onRetry: widget.onRetryPartialErrors,
            ),
          ),
          if (!widget.state.showsContent || visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: PaneStateView(
                state: widget.state.showsContent
                    ? PaneStateViewModel.empty(
                        title: widget.resources.isEmpty ? '暂无资源' : '没有匹配项',
                        message: widget.resources.isEmpty
                            ? '连接 PVE 后，QEMU 虚拟机与 LXC 容器会显示在这里。'
                            : '请调整搜索内容或筛选条件。',
                      )
                    : widget.state,
                onAction: widget.onStateAction,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: InventorySurface(
                  padding: EdgeInsets.zero,
                  radius: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < visible.length;
                          index++
                        ) ...[
                          if (index > 0)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFEFF1F6),
                            ),
                          _ResourceRow(
                            resource: visible[index],
                            selected:
                                visible[index].id == widget.selectedResourceId,
                            onTap: () =>
                                widget.onResourceSelected(visible[index]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Text(
                  '显示 ${visible.length} / ${scoped.length} 台资源',
                  textAlign: TextAlign.center,
                  style: inventoryText(11, color: const Color(0xFF7C899F)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
    required this.selected,
    required this.onTap,
  });
  final ResourceViewModel resource;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFF4F6FF) : Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InventoryIcon(
                  icon: resource.kind == ResourceKind.qemu
                      ? PveIconName.monitor
                      : PveIconName.box,
                  secondary: resource.kind == ResourceKind.lxc,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: inventoryText(
                          14,
                          color: const Color(0xFF202D45),
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${resource.guestId} · ${resource.nodeName} · ${resource.kind == ResourceKind.qemu ? '虚拟机' : '容器'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: inventoryText(11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                ResourceStatusBadge(resource.status, compact: true),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: InventoryUsage(
                    label: 'CPU',
                    value: formatPercent(resource.cpuUsage),
                    progress: resource.cpuUsage,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: InventoryUsage(
                    label: '内存',
                    value: formatPercent(
                      memoryFraction(
                        resource.memoryUsedBytes,
                        resource.memoryTotalBytes,
                      ),
                    ),
                    progress: memoryFraction(
                      resource.memoryUsedBytes,
                      resource.memoryTotalBytes,
                    ),
                    secondary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
