import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
});

void logError(WidgetRef ref, Object error, StackTrace stack) {
  ref
      .read(loggerProvider)
      .e('Unhandled exception', error: error, stackTrace: stack);
}
