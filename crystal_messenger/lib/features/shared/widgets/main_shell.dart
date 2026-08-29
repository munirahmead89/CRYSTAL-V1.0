import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/updates')) {
      currentIndex = 1;
    } else if (location.startsWith('/calls')) {
      currentIndex = 2;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          HapticFeedback.lightImpact();
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/updates');
              break;
            case 2:
              context.go('/calls');
              break;
          }
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withAlpha(30),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.update_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.update, color: AppColors.primary),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.phone, color: AppColors.primary),
            label: 'Calls',
          ),
        ],
      ),
    );
  }
}
