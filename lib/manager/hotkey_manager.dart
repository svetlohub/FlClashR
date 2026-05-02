import 'package:flutter/material.dart';

// Desktop-only feature. Passes through on Android.
class HotKeyManager extends StatelessWidget {
  final Widget child;
  const HotKeyManager({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
