import 'package:intl/intl.dart';

class DateTimeUtils {
  // Private constructor prevents instantiation of static class.
  DateTimeUtils._();

  //TODO: Use UTC time (toUtc()).

  // Define a string representation of a timestampt,
  // that is usable in both local filenames and urls.
  // e.g. 20260612-134527-123
  static final DateFormat _filenameFormat = DateFormat('yyyyMMdd-HHmmss-SSS');

  static final String regExpPattern = r'\d{8}-\d{6}-\d{3}';

  static String filenameFormat(DateTime datetime) {
    return _filenameFormat.format(datetime.toUtc());
  }

  static DateTime parseFilenameFormat(String ts) {
    // e.g. 20260612-134527-123
    //final parts = ts.split('-');
    //final datePart = parts[0];
    //final timePart = parts[1];
    //final msPart = parts[2];

    final date = ts.substring(0, 8);
    final time = ts.substring(9, 15);
    final ms = ts.substring(16);

    return DateTime.utc(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(4, 6)),
      int.parse(date.substring(6, 8)),
      int.parse(time.substring(0, 2)),
      int.parse(time.substring(2, 4)),
      int.parse(time.substring(4, 6)),
      int.parse(ms),
    );
  }
}
