import 'package:flutter/material.dart';

import '../widgets/inventory_widgets.dart';
import '../widgets/pve_icon.dart';
import '../view_models.dart';
import '../widgets/feedback_views.dart';
import '../widgets/status_badge.dart';

class NodeListPane extends StatefulWidget {
  const NodeListPane({
    super.key,
    required this.nodes,
    required this.connections,
    required this.filter,
    required this.onFilterChanged,
    required this.onNodeSelected,
    this.selectedNodeId,
    this.state = const PaneStateViewModel(),
    this.partialErrors = const [],
    this.onStateAction,
    this.onRetryPartialErrors,
    this.onRefresh,
    this.lastUpdatedAt,
    this.connectionOnline,
  });

  final List<NodeViewModel> nodes;
  final List<ConnectionOptionViewModel> connections;
  final NodeFilterViewModel filter;
  final ValueChanged<NodeFilterViewModel> onFilterChanged;
  final ValueChanged<NodeViewModel> onNodeSelected;
  final String? selectedNodeId;
  final PaneStateViewModel state;
  final List<ScopedErrorViewModel> partialErrors;
  final UiAction? onStateAction;
  final UiAction? onRetryPartialErrors;
  final UiAction? onRefresh;
  final DateTime? lastUpdatedAt;
  final bool? connectionOnline;

  @override
  State<NodeListPane> createState() => _NodeListPaneState();
}

class _NodeListPaneState extends State<NodeListPane> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filter.query);
  }

  @override
  void didUpdateWidget(NodeListPane oldWidget) {
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

  List<NodeViewModel> get _visibleNodes {
    final query = widget.filter.query.trim().toLowerCase();
    return widget.nodes
        .where((node) {
          if (widget.filter.connectionId != null &&
              widget.filter.connectionId != node.connectionId) {
            return false;
          }
          if (query.isEmpty) return true;
          return node.name.toLowerCase().contains(query) ||
              node.connectionName.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleNodes;
    final scoped = widget.nodes
        .where(
          (n) =>
              widget.filter.connectionId == null ||
              n.connectionId == widget.filter.connectionId,
        )
        .toList();
    final value =
        widget.filter.connectionId ??
        (widget.connections.length == 1 ? widget.connections.first.id : 'all');
    final online =
        widget.connectionOnline ??
        (widget.state.showsContent &&
            widget.connections.isNotEmpty &&
            !widget.partialErrors.any(
              (e) => value == 'all' || e.connectionId == value,
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
                      'node-connection-${widget.filter.connectionId ?? 'all'}',
                    ),
                    value: value,
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
                    title: '宿主节点',
                    unit: '个',
                    total: scoped.length,
                    counts: {
                      '在线': scoped.where((n) => n.isOnline).length,
                      '离线': scoped
                          .where((n) => n.status == NodeStatus.offline)
                          .length,
                      if (scoped.any((n) => n.status == NodeStatus.unknown))
                        '未知': scoped
                            .where((n) => n.status == NodeStatus.unknown)
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
                    hintText: '搜索节点或连接',
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
                    onChanged: (q) => widget.onFilterChanged(
                      widget.filter.copyWith(query: q),
                    ),
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
                        title: widget.nodes.isEmpty ? '暂无节点' : '没有匹配项',
                        message: widget.nodes.isEmpty
                            ? '连接 PVE 后，宿主节点会显示在这里。'
                            : '请调整搜索内容或连接筛选。',
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
                          _NodeRow(
                            node: visible[index],
                            selected:
                                visible[index].id == widget.selectedNodeId,
                            onTap: () => widget.onNodeSelected(visible[index]),
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
                  '显示 ${visible.length} / ${scoped.length} 个节点',
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

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.selected,
    required this.onTap,
  });
  final NodeViewModel node;
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
                const InventoryIcon(icon: PveIconName.server),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
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
                        node.connectionName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: inventoryText(11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                NodeStatusBadge(node.status, compact: true),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: InventoryUsage(
                    label: 'CPU',
                    value: formatPercent(node.cpuUsage),
                    progress: node.cpuUsage,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: InventoryUsage(
                    label: '内存',
                    value: formatPercent(
                      memoryFraction(
                        node.memoryUsedBytes,
                        node.memoryTotalBytes,
                      ),
                    ),
                    progress: memoryFraction(
                      node.memoryUsedBytes,
                      node.memoryTotalBytes,
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
