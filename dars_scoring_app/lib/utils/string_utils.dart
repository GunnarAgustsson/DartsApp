String shortenName(String name, {int maxLength = 12}) {
  if (name.length <= maxLength) return name;
  final parts = name.split(' ');
  if (parts.length == 1) {
    return name.substring(0, maxLength - 3) + '...';
  }
  final first = parts.first;
  final last = parts.sublist(1).join(' ');
  int allowedLast = maxLength - first.length - 4; // 1 space + 3 dots
  String shortLast = allowedLast > 0 ? last.substring(0, allowedLast) : '';
  return '$first ${shortLast}...';
}