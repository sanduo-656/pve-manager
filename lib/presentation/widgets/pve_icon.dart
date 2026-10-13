import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PveIconName {
  layers('layers'),
  server('server'),
  link('link'),
  refreshCw('refresh-cw'),
  arrowLeft('arrow-left'),
  monitor('monitor'),
  box('box'),
  search('search'),
  slidersHorizontal('sliders-horizontal'),
  chevronDown('chevron-down'),
  terminal('terminal'),
  power('power'),
  rotateCw('rotate-cw'),
  arrowRight('arrow-right'),
  activity('activity'),
  shieldCheck('shield-check'),
  userRound('user-round'),
  lockKeyhole('lock-keyhole'),
  eye('eye'),
  eyeOff('eye-off'),
  x('x'),
  signal('signal'),
  wifi('wifi'),
  batteryFull('battery-full'),
  plus('plus'),
  inbox('inbox'),
  triangleAlert('triangle-alert'),
  loaderCircle('loader-circle'),
  check('check'),
  pencil('pencil'),
  logIn('log-in');

  const PveIconName(this.assetName);
  final String assetName;
}

/// Lucide artwork matching the rt2w7 reference.
class PveIcon extends StatelessWidget {
  const PveIcon(this.name, {super.key, this.size = 20, this.color});
  final PveIconName name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/${name.assetName}.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? const Color(0xFF56647D),
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}
