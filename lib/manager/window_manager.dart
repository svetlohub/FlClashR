import 'package:flutter/material.dart';

// Desktop-only feature. Passes through on Android.
class WindowManager extends StatelessWidget {
  final Widget child;
  const WindowManager({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class WindowHeaderContainer extends StatelessWidget {
  final Widget child;
  const WindowHeaderContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
