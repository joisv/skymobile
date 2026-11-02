class Formatters {
  static String currency(double amount) {
    final intVal = amount.toInt();
    final str = intVal.toString();
    final buffer = StringBuffer('Rp ');
    final length = str.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static String number(num amount) {
    final intVal = amount.toInt();
    final isNegative = intVal < 0;
    final str = intVal.abs().toString();
    final buffer = StringBuffer(isNegative ? '-' : '');
    final length = str.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  /// Normalizes UTC DateTime to Asia/Jakarta (WIB, UTC+7)
  static DateTime toWib(DateTime dt) {
    if (dt.isUtc) {
      final wib = dt.add(const Duration(hours: 7));
      return DateTime(wib.year, wib.month, wib.day, wib.hour, wib.minute, wib.second);
    }
    return dt;
  }

  static String date(DateTime dt) {
    final local = toWib(dt);
    final day = local.day.toString().padLeft(2, '0');
    final month = _monthNames[local.month - 1];
    return '$day $month ${local.year}';
  }

  static String time(DateTime dt) {
    final local = toWib(dt);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String dateTime(DateTime dt) {
    return '${date(dt)}, ${time(dt)}';
  }

  static String dateRange(DateTime start, DateTime end) {
    return '${date(start)} - ${date(end)}';
  }

  static String formatCurrency(double amount) => currency(amount);
  static String formatDate(DateTime dt) => date(dt);
  static String formatDateTime(DateTime dt) => dateTime(dt);
  static String formatTime(DateTime dt) => time(dt);
}

typedef AppFormatters = Formatters;
