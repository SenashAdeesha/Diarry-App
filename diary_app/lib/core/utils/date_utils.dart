import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormatter instance = DateFormatter._();
  DateFormatter._();

  String formatFull(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }

  String formatShort(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return formatShort(date);
  }
}
