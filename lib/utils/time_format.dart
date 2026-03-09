String formatChatTime(DateTime dt) {
  final now = DateTime.now();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final time = '$hour:$minute';

  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return time;
  }

  final yesterday = now.subtract(const Duration(days: 1));
  if (dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day) {
    return 'Yesterday $time';
  }

  return '${dt.day}/${dt.month} $time';
}
