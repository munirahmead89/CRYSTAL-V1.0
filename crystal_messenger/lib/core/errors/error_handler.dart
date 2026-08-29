import '../utils/logger.dart';
import 'app_exception.dart';

class ErrorHandler {
  static AppException handle(Object error, [StackTrace? stackTrace]) {
    Logger.error('ErrorHandler', 'Caught error', error, stackTrace);

    if (error is AppException) return error;

    final message = error.toString();

    if (message.contains('SocketException') || message.contains('Connection refused')) {
      return AppException.network();
    }
    if (message.contains('401') || message.contains('Unauthorized')) {
      return AppException.auth();
    }
    if (message.contains('500') || message.contains('Server error')) {
      return AppException.server();
    }

    return AppException.unknown(error);
  }
}
