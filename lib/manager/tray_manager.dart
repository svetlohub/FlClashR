import 'package:flutter/material.dart';

// Desktop-only feature. Passes through on Android.
class TrayManager extends StatelessWidget {
  final Widget child;
  const TrayManager({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
