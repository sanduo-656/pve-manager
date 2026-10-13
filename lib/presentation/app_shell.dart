import 'package:flutter/material.dart';

import 'theme/pve_theme.dart';
import 'view_models.dart';
import 'widgets/pve_icon.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.body,
    this.title = 'PVE 管家',
    this.actions = const [],
    this.floatingActionButton,
    this.showAppBar = true,
  });
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;
  final Widget body;
  final String title;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final subtitle = switch (selectedSection) {
      AppSection.resources => '你的基础设施，一目了然',
      AppSection.nodes => '集群节点与运行状态',
      AppSection.connections => '管理你的服务器连接',
    };
    final titleStyle = PveTheme.text(25, 36, weight: FontWeight.w700);
    final subtitleStyle = PveTheme.text(12, 17, color: const Color(0xFF68758C));
    // Scaffold needs the app-bar height before laying out its child. Measure
    // wrapped text at the available width so large fonts and versioned titles
    // cannot grow beyond the reserved header space.
    final headerWidth =
        (MediaQuery.sizeOf(context).width - 44 - actions.length * 48).clamp(
          1.0,
          double.infinity,
        );
    double textHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout(maxWidth: headerWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final headerHeight =
        (34 +
                textHeight(title, titleStyle) +
                4 +
                textHeight(subtitle, subtitleStyle))
            .clamp(91.0, double.infinity);
    final navigationHeight = (37 + textScaler.scale(11) * 16 / 11).clamp(
      66.0,
      double.infinity,
    );
    return Scaffold(
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: Size.fromHeight(headerHeight),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: titleStyle),
                            const SizedBox(height: 4),
                            Text(subtitle, style: subtitleStyle),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(top: !showAppBar, bottom: false, child: body),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            key: const ValueKey('app-navigation-bar'),
            height: navigationHeight,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(33),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(33),
              border: Border.all(color: const Color(0xFFE6EAF1)),
            ),
            child: Row(
              children: [
                for (final section in AppSection.values) ...[
                  if (section != AppSection.resources) const SizedBox(width: 5),
                  Expanded(
                    child: _NavigationItem(
                      section: section,
                      selected: section == selectedSection,
                      onTap: () => onSectionSelected(section),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });
  final AppSection section;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final label = switch (section) {
      AppSection.resources => '资源',
      AppSection.nodes => '节点',
      AppSection.connections => '连接',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? const Color(0xFFE9EDFF) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          key: ValueKey('navigation-${section.name}'),
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PveIcon(
                switch (section) {
                  AppSection.resources => PveIconName.layers,
                  AppSection.nodes => PveIconName.server,
                  AppSection.connections => PveIconName.link,
                },
                size: 20,
                color: selected
                    ? PveTheme.primaryBlue
                    : const Color(0xFF8A94A8),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: PveTheme.text(
                  11,
                  16,
                  weight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? PveTheme.primaryBlue
                      : PveTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
