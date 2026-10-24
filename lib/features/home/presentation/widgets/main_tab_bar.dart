import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// The main Crystal Messenger shell tabs: Chats / Updates / Calls.
///
/// Active tab styling matches WhatsApp exactly:
///   • Green (#00FF00) bottom-border underline indicator.
///   • Green text for the selected label.
///   • Subtle green-tinted background behind the active tab.
///   • Unselected tabs use the standard surface colour + muted text.
///
/// Tab headers are clean text-only — no unread badges on the top tab row
/// (unread counts live on the individual chat tiles and the bottom nav).
class MainTabBar extends StatelessWidget {
  const MainTabBar({super.key, required this.index, required this.onChanged});

  static const labels = ['Chats', 'Updates', 'Calls'];

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkResponse(
                onTap: () => onChanged(i),
                radius: 48,
                highlightColor: CrystalColors.green24,
                splashColor: CrystalColors.green24,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // Subtle green tint on the active tab background.
                    color: i == index
                        ? CrystalColors.green12
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        // Green underline indicator — same as WhatsApp.
                        color: i == index
                            ? CrystalColors.green
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: i == index
                          ? FontWeight.bold
                          : FontWeight.w400,
                      // Green text for the active tab, muted for others.
                      color: i == index
                          ? CrystalColors.green
                          : scheme.onSurfaceVariant,
                    ),
                    child: Text(labels[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
