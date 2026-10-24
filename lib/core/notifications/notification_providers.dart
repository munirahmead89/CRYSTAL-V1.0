import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';

export 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
