import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_provider.dart';
import 'logger_service.dart';

final loggerProvider = Provider<LoggerService>((ref) {
  final config = ref.watch(appConfigProvider);
  return createLogger(verbosity: config.logVerbosity);
});
