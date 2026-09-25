import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What kind of block an event is. Drives colour and the Home summary.
enum EventCategory { training, work, study, meal, personal, recovery }

extension EventCategoryInfo on EventCategory {
  String get label => switch (this) {
    EventCategory.training => 'Training',
    EventCategory.work => 'Work',
    EventCategory.study => 'Study',
    EventCategory.meal => 'Meal',
    EventCategory.personal => 'Personal',
    EventCategory.recovery => 'Recovery',
  };
}

/// One entry in Ali's day. His own data — typed in by him, stored on this
/// machine only, never invented by VOLTRA.
class ScheduleEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final EventCategory category;
  final String? notes;

  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.category,
    this.notes,
  });

  Duration get duration => end.difference(start);

  bool isOn(DateTime day) =>
      start.year == day.year &&
      start.month == day.month &&
      start.day == day.day;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'category': category.name,
    'notes': notes,
  };

  static ScheduleEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = DateTime.tryParse(json['start']?.toString() ?? '');
    final end = DateTime.tryParse(json['end']?.toString() ?? '');
    final title = json['title']?.toString();
    final id = json['id']?.toString();
    if (start == null || end == null || title == null || id == null) {
      return null;
    }
    return ScheduleEvent(
      id: id,
      title: title,
      start: start,
      end: end,
      category: EventCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => EventCategory.personal,
      ),
      notes: json['notes']?.toString(),
    );
  }
}

/// Ali's schedule, persisted locally with shared_preferences.
///
/// Starts empty. An empty schedule is shown as empty — VOLTRA does not seed
/// it with a sample day, because a sample day on Home would be indistinguish-
/// able from a real one.
class ScheduleStore extends ChangeNotifier {
  static const String _key = 'voltra.schedule.events';

  final List<ScheduleEvent> _events = <ScheduleEvent>[];
  SharedPreferences? _prefs;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<ScheduleEvent> get all =>
      List<ScheduleEvent>.unmodifiable(_events..sort(_byStart));

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _events
            ..clear()
            ..addAll(
              decoded.map(ScheduleEvent.fromJson).whereType<ScheduleEvent>(),
            );
        }
      } on FormatException {
        // A corrupt store is dropped rather than half-read.
        _events.clear();
      }
    }

    _loaded = true;
    notifyListeners();
  }

  List<ScheduleEvent> forDay(DateTime day) =>
      _events.where((e) => e.isOn(day)).toList()..sort(_byStart);

  List<ScheduleEvent> forWeekOf(DateTime day) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: day.weekday % 7));
    final end = start.add(const Duration(days: 7));
    return _events
        .where((e) => !e.start.isBefore(start) && e.start.isBefore(end))
        .toList()
      ..sort(_byStart);
  }

  /// The next event that has not started yet, today or later.
  ScheduleEvent? get next {
    final now = DateTime.now();
    final upcoming = _events.where((e) => e.start.isAfter(now)).toList()
      ..sort(_byStart);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// The event happening right now, if any.
  ScheduleEvent? get current {
    final now = DateTime.now();
    for (final e in _events) {
      if (e.start.isBefore(now) && e.end.isAfter(now)) return e;
    }
    return null;
  }

  Future<void> add(ScheduleEvent event) async {
    _events.add(event);
    await _persist();
  }

  Future<void> remove(String id) async {
    _events.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    _events.sort(_byStart);
    await _prefs?.setString(
      _key,
      jsonEncode(_events.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  static int _byStart(ScheduleEvent a, ScheduleEvent b) =>
      a.start.compareTo(b.start);
}
