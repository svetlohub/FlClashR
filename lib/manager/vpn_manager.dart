import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/providers/app.dart';
import 'package:flclashx/providers/state.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps the app tree and shows a system notification when VPN becomes active.
class VpnManager extends ConsumerStatefulWidget {
  const VpnManager({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<VpnManager> createState() => _VpnManagerState();
}

class _VpnManagerState extends ConsumerState<VpnManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(vpnStateProvider, (_, __) => _maybeShowTip());
  }

  void _maybeShowTip() {
    debouncer.call(FunctionTag.vpnTip, () {
      if (ref.read(runTimeProvider.notifier).isStart) {
        globalState.showNotifier(appLocalizations.vpnTip);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
