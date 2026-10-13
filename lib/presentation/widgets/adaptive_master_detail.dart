import 'package:flutter/material.dart';

/// A single resource screen matching the design on every display width.
class AdaptiveMasterDetail extends StatelessWidget {
  const AdaptiveMasterDetail({
    super.key,
    required this.master,
    required this.detail,
    this.showDetailOnCompact = false,
  });
  final Widget master;
  final Widget detail;
  final bool showDetailOnCompact;
  @override
  Widget build(BuildContext context) => showDetailOnCompact ? detail : master;
}
