#!/bin/bash
# Raketa build fix — run in /workspaces/FlClashR
set -e
echo "Fixing lib/widgets/setting.dart..."

cat > lib/widgets/setting.dart << 'DART'
import 'package:flclashx/common/common.dart';
import 'package:flutter/material.dart';

import 'card.dart';

class SettingInfoCard extends StatelessWidget {

  const SettingInfoCard(
      this.info, {
        super.key,
        this.isSelected,
        required this.onPressed,
      });
  final Info info;
  final bool? isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CommonCard(
      isSelected: isSelected,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Icon(info.iconData),
            ),
            const SizedBox(
              width: 8,
            ),
            Flexible(
              child: Text(
                info.label,
                style: context.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
}

class SettingTextCard extends StatelessWidget {

  const SettingTextCard(
      this.text, {
        super.key,
        this.isSelected,
        required this.onPressed,
      });
  final String text;
  final bool? isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CommonCard(
      onPressed: onPressed,
      isSelected: isSelected,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: context.textTheme.bodyMedium,
        ),
      ),
    );
}
DART

echo "✓ lib/widgets/setting.dart fixed (SettingInfoCard + SettingTextCard only, NO ProxiesSetting)"

# Verify
CLASSES=$(grep "^class " lib/widgets/setting.dart)
echo "  Classes in file: $CLASSES"

if echo "$CLASSES" | grep -q "ProxiesSetting"; then
  echo "✗ ERROR: ProxiesSetting still present!"
  exit 1
fi

echo ""
echo "Committing..."
git add lib/widgets/setting.dart
git commit -m "fix: remove ProxiesSetting from widgets/setting.dart — was uploaded to wrong file, causing duplicate class ambiguity"
git pull --rebase origin main --quiet
git push origin main
echo ""
echo "✅ Done! GitHub Actions will rebuild automatically."
echo "   Watch: https://github.com/svetlohub/FlClashR/actions"
