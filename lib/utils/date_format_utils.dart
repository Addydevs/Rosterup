// Centralised date/time formatting helpers used across the app.
//
// Usage:
//   import '../utils/date_format_utils.dart';
//   final f = FormattedDate(game.dateTime);
//   Text('${f.weekday}, ${f.month} ${f.day} · ${f.time}');

class FormattedDate {
  FormattedDate(this.date);

  final DateTime date;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get weekday => _weekdays[date.weekday - 1];
  String get month => _months[date.month - 1];
  int get day => date.day;
  int get hour {
    final h = date.hour;
    return h == 0 || h == 12 ? 12 : h % 12;
  }

  String get minute => date.minute.toString().padLeft(2, '0');
  String get period => date.hour < 12 ? 'AM' : 'PM';

  /// e.g. "11:30 AM"
  String get time => '$hour:$minute $period';

  /// e.g. "Mon, Jan 5"
  String get shortDate => '$weekday, $month $day';

  /// e.g. "Mon, Jan 5 · 11:30 AM"
  String get full => '$shortDate · $time';
}
