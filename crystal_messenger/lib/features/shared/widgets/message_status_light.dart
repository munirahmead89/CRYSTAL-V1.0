import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum MessageTrafficLight {
  sent,
  delivered,
  viewed,
}

class MessageStatusLight extends StatelessWidget {
  final MessageTrafficLight status;
  final double size;

  const MessageStatusLight({
    super.key,
    required this.status,
    this.size = 8,
  });

  Color get _color {
    switch (status) {
      case MessageTrafficLight.sent:
        return AppColors.error;
      case MessageTrafficLight.delivered:
        return AppColors.warning;
      case MessageTrafficLight.viewed:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _color.withOpacity(0.4),
            blurRadius: 3,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
