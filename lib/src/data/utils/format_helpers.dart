String formatRupee(num amount) {
  final raw = amount.round().toString();
  final buf = StringBuffer();
  final len = raw.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(',');
    buf.write(raw[i]);
  }
  return '₹ $buf';
}

String formatRupeeCompact(num amount) {
  if (amount >= 10000000) {
    return '₹ ${(amount / 10000000).toStringAsFixed(1)}Cr';
  }
  if (amount >= 100000) {
    return '₹ ${(amount / 100000).toStringAsFixed(1)}L';
  }
  if (amount >= 1000) {
    return '₹ ${(amount / 1000).toStringAsFixed(1)}K';
  }
  return formatRupee(amount);
}

String formatDobForApi(String ddMmYyyy) {
  final parts = ddMmYyyy.split('/');
  if (parts.length != 3) return ddMmYyyy;
  return '${parts[2]}-${parts[1]}-${parts[0]}';
}

String formatDobForUi(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String formatDateLabel(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDonationGroupLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_monthLabels[local.month - 1]} ${local.day}';
}

/// API dates arrive as UTC ISO; format in device local timezone.
String formatDonationDateTime(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = _monthLabels[local.month - 1];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'pm' : 'am';
  return '$day $month, ${local.year} • $hour:$minute $period';
}

const _monthLabelsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatTargetDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_monthLabelsFull[local.month - 1]}, ${local.year}';
}

/// API dates arrive as UTC ISO; always format in the device local timezone
/// so times match admin (Asia/Kolkata on Indian devices).
String _formatTimeAmPm(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'pm' : 'am';
  return '$hour:$minute $period';
}

/// e.g. `07 Jun, 2026 • 10:45 am - 3:30pm`
String formatEventDateTimeRange(DateTime? start, [DateTime? end]) {
  if (start == null) return '';
  final localStart = start.toLocal();
  final day = localStart.day.toString().padLeft(2, '0');
  final month = _monthLabels[localStart.month - 1];
  final datePart = '$day $month, ${localStart.year}';
  if (end == null) {
    return '$datePart • ${_formatTimeAmPm(localStart)}';
  }
  return '$datePart • ${_formatTimeAmPm(localStart)} - ${_formatTimeAmPm(end)}';
}

/// e.g. `20 Jun 2026`
String formatEventShortDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = _monthLabels[local.month - 1];
  return '$day $month ${local.year}';
}

/// e.g. `May 2026`
String formatEventMonthYear(DateTime date) {
  final local = date.toLocal();
  return '${_monthLabelsFull[local.month - 1]} ${local.year}';
}

String formatEventTime(DateTime? date) {
  if (date == null) return '';
  return _formatTimeAmPm(date);
}

/// e.g. `10:45 am - 3:30 pm` (start only when end is null)
String formatEventTimeRange(DateTime? start, [DateTime? end]) {
  if (start == null) return '';
  if (end == null) return _formatTimeAmPm(start);
  return '${_formatTimeAmPm(start)} - ${_formatTimeAmPm(end)}';
}
