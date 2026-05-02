/// A date in an in-world calendar. All fields refer to the world's own
/// calendar units, not Earth's. `monthIndex` is 0-based; `day` is 1-based.
class WorldDate implements Comparable<WorldDate> {
  const WorldDate({
    required this.year,
    required this.monthIndex,
    required this.day,
  });

  final int year;
  final int monthIndex;
  final int day;

  WorldDate copyWith({int? year, int? monthIndex, int? day}) => WorldDate(
        year: year ?? this.year,
        monthIndex: monthIndex ?? this.monthIndex,
        day: day ?? this.day,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldDate &&
          other.year == year &&
          other.monthIndex == monthIndex &&
          other.day == day;

  @override
  int get hashCode => Object.hash(year, monthIndex, day);

  @override
  int compareTo(WorldDate other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = monthIndex.compareTo(other.monthIndex);
    if (byMonth != 0) return byMonth;
    return day.compareTo(other.day);
  }

  @override
  String toString() => 'WorldDate($year, $monthIndex, $day)';
}
