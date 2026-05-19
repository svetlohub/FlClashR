import 'dart:convert';

import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnounceWidget extends ConsumerWidget {
  const AnnounceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = _resolveText(ref);
    if (text == null) return const SizedBox.shrink();

    return CommonCard(
      onPressed: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: RichText(
          text: TextSpan(children: _buildSpans(context, text)),
        ),
      ),
    );
  }

  String? _resolveText(WidgetRef ref) {
    final headers = ref.watch(currentProfileProvider)?.providerHeaders;
    final raw = headers?['announce'];
    if (raw == null || raw.isEmpty) return null;

    final toDecode = raw.startsWith('base64:') ? raw.substring(7) : raw;
    try {
      return utf8.decode(base64.decode(base64.normalize(toDecode)));
    } catch (_) {
      return raw; // fall back to raw if not valid base64
    }
  }

  static final _urlRe = RegExp(r'https?://\S+', caseSensitive: false);

  List<InlineSpan> _buildSpans(BuildContext context, String text) {
    final style     = Theme.of(context).textTheme.bodyLarge;
    final linkStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final m in _urlRe.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: style));
      }
      final url = m.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => globalState.openUrl(url),
      ));
      cursor = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }
    return spans;
  }
}
