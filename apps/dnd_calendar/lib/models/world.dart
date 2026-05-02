import 'package:calendar_engine/calendar_engine.dart' as engine;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'world.freezed.dart';
part 'world.g.dart';

/// One month in a world's calendar — persistence shape, mirrors
/// `engine.MonthDef` 1:1.
@freezed
class MonthData with _$MonthData {
  const MonthData._();
  const factory MonthData({required String name, required int days}) =
      _MonthData;
  factory MonthData.fromJson(Map<String, dynamic> json) =>
      _$MonthDataFromJson(json);

  engine.MonthDef toEngine() => engine.MonthDef(name: name, days: days);
  factory MonthData.fromEngine(engine.MonthDef m) =>
      MonthData(name: m.name, days: m.days);
}

@freezed
class LeapRuleData with _$LeapRuleData {
  const LeapRuleData._();
  const factory LeapRuleData({
    required int everyNYears,
    required int extraDayInMonthIndex,
  }) = _LeapRuleData;
  factory LeapRuleData.fromJson(Map<String, dynamic> json) =>
      _$LeapRuleDataFromJson(json);

  engine.LeapRule toEngine() => engine.LeapRule(
        everyNYears: everyNYears,
        extraDayInMonthIndex: extraDayInMonthIndex,
      );
  factory LeapRuleData.fromEngine(engine.LeapRule r) => LeapRuleData(
        everyNYears: r.everyNYears,
        extraDayInMonthIndex: r.extraDayInMonthIndex,
      );
}

@freezed
class MoonData with _$MoonData {
  const MoonData._();
  const factory MoonData({
    required String name,
    required int periodDays,
    required int offsetDays,
    required String color,
  }) = _MoonData;
  factory MoonData.fromJson(Map<String, dynamic> json) =>
      _$MoonDataFromJson(json);

  engine.MoonDef toEngine() => engine.MoonDef(
        name: name,
        periodDays: periodDays,
        offsetDays: offsetDays,
        color: color,
      );
  factory MoonData.fromEngine(engine.MoonDef m) => MoonData(
        name: m.name,
        periodDays: m.periodDays,
        offsetDays: m.offsetDays,
        color: m.color,
      );
}

@freezed
class WorldDateData with _$WorldDateData {
  const WorldDateData._();
  const factory WorldDateData({
    required int year,
    required int monthIndex,
    required int day,
  }) = _WorldDateData;
  factory WorldDateData.fromJson(Map<String, dynamic> json) =>
      _$WorldDateDataFromJson(json);

  engine.WorldDate toEngine() =>
      engine.WorldDate(year: year, monthIndex: monthIndex, day: day);
  factory WorldDateData.fromEngine(engine.WorldDate d) =>
      WorldDateData(year: d.year, monthIndex: d.monthIndex, day: d.day);
}

/// Calendar configuration as stored on a world doc. Includes `currentDate`
/// (a runtime field) for storage convenience even though the engine treats
/// it separately.
@freezed
class CalendarConfigData with _$CalendarConfigData {
  const CalendarConfigData._();
  const factory CalendarConfigData({
    required int daysPerWeek,
    required List<String> weekdayNames,
    required List<MonthData> months,
    required String epochName,
    required int startYear,
    LeapRuleData? leapRule,
    required WorldDateData currentDate,
    @Default([]) List<MoonData> moons,
  }) = _CalendarConfigData;
  factory CalendarConfigData.fromJson(Map<String, dynamic> json) =>
      _$CalendarConfigDataFromJson(json);

  engine.CalendarConfig toEngine() => engine.CalendarConfig(
        daysPerWeek: daysPerWeek,
        weekdayNames: weekdayNames,
        months: [for (final m in months) m.toEngine()],
        epochName: epochName,
        startYear: startYear,
        leapRule: leapRule?.toEngine(),
        moons: [for (final m in moons) m.toEngine()],
      );
}

/// Top-level world document.
@freezed
class World with _$World {
  const World._();
  const factory World({
    required String id,
    required String ownerUid,
    required String name,
    required String joinCode,
    required CalendarConfigData calendar,
    @TimestampConverter() DateTime? createdAt,
  }) = _World;
  factory World.fromJson(Map<String, dynamic> json) => _$WorldFromJson(json);

  factory World.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return World.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toFirestore() {
    final j = toJson();
    j.remove('id'); // id lives in the doc path, not the data
    return j;
  }
}

/// Default calendar to seed new worlds with: Earth-like 7-day week, 12 months
/// of 30 days, single moon, no leap rule, year 1.
CalendarConfigData defaultCalendar() => const CalendarConfigData(
      daysPerWeek: 7,
      weekdayNames: [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ],
      months: [
        MonthData(name: 'Firstmonth', days: 30),
        MonthData(name: 'Secondmonth', days: 30),
        MonthData(name: 'Thirdmonth', days: 30),
        MonthData(name: 'Fourthmonth', days: 30),
        MonthData(name: 'Fifthmonth', days: 30),
        MonthData(name: 'Sixthmonth', days: 30),
        MonthData(name: 'Seventhmonth', days: 30),
        MonthData(name: 'Eighthmonth', days: 30),
        MonthData(name: 'Ninthmonth', days: 30),
        MonthData(name: 'Tenthmonth', days: 30),
        MonthData(name: 'Eleventhmonth', days: 30),
        MonthData(name: 'Twelfthmonth', days: 30),
      ],
      epochName: 'AC',
      startYear: 1,
      leapRule: null,
      currentDate: WorldDateData(year: 1, monthIndex: 0, day: 1),
      moons: [
        MoonData(name: 'Moon', periodDays: 28, offsetDays: 0, color: '#dddddd'),
      ],
    );

/// Firestore Timestamp ↔ DateTime converter for json_serializable.
class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Object? toJson(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);
}
