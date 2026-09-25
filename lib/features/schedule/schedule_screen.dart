import 'package:flutter/material.dart';

import '../../app/voltra_services.dart';
import '../../core/health_format.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/voltra_card.dart';
import 'schedule_store.dart';

enum ScheduleView { day, week, month }

/// Ali's day, week and month. Everything here is data he entered; VOLTRA
/// never seeds it with a sample plan.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  ScheduleView _view = ScheduleView.day;
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: scheduleStore,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                _viewSelector(context),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _addEvent,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!scheduleStore.isLoaded)
              VoltraCard(
                child: Text(
                  'Loading your schedule…',
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
              )
            else
              switch (_view) {
                ScheduleView.day => _dayView(context),
                ScheduleView.week => _weekView(context),
                ScheduleView.month => _monthView(context),
              },
          ],
        );
      },
    );
  }

  Widget _viewSelector(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final view in ScheduleView.values)
            GestureDetector(
              onTap: () => setState(() => _view = view),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: view == _view
                      ? p.accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  view.name[0].toUpperCase() + view.name.substring(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: view == _view ? p.accent : p.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayView(BuildContext context) {
    final p = context.palette;
    final events = scheduleStore.forDay(_anchor);
    final current = scheduleStore.current;

    return VoltraCard(
      title: _fullDate(_anchor),
      icon: Icons.today_outlined,
      trailing: _navButtons(const Duration(days: 1)),
      child: events.isEmpty
          ? Text(
              'Nothing scheduled. Use Add to create your first block.',
              style: TextStyle(color: p.textMuted, fontSize: 13),
            )
          : Column(
              children: [
                for (final event in events)
                  _EventRow(
                    event: event,
                    live: current?.id == event.id,
                    onDelete: () => scheduleStore.remove(event.id),
                  ),
              ],
            ),
    );
  }

  Widget _weekView(BuildContext context) {
    final p = context.palette;
    final start = DateTime(
      _anchor.year,
      _anchor.month,
      _anchor.day,
    ).subtract(Duration(days: _anchor.weekday % 7));

    return VoltraCard(
      title: 'Week of ${_shortDate(start)}',
      icon: Icons.view_week_outlined,
      trailing: _navButtons(const Duration(days: 7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 7; i++) ...[
            Builder(
              builder: (context) {
                final day = start.add(Duration(days: i));
                final events = scheduleStore.forDay(day);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          _shortDate(day),
                          style: TextStyle(
                            color: _isToday(day) ? p.accent : p.textSecondary,
                            fontSize: 12.5,
                            fontWeight: _isToday(day)
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: events.isEmpty
                            ? Text(
                                '—',
                                style: TextStyle(
                                  color: p.textMuted,
                                  fontSize: 12.5,
                                ),
                              )
                            : Text(
                                events
                                    .map(
                                      (e) =>
                                          '${formatClock(e.start)} ${e.title}',
                                    )
                                    .join('   ·   '),
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 12.5,
                                  height: 1.5,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _monthView(BuildContext context) {
    final p = context.palette;
    final first = DateTime(_anchor.year, _anchor.month, 1);
    final daysInMonth = DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final busy = <int, int>{};

    for (var d = 1; d <= daysInMonth; d++) {
      final count = scheduleStore
          .forDay(DateTime(_anchor.year, _anchor.month, d))
          .length;
      if (count > 0) busy[d] = count;
    }

    return VoltraCard(
      title: '${_monthName(first.month)} ${first.year}',
      icon: Icons.calendar_month_outlined,
      trailing: _navButtons(const Duration(days: 30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            busy.isEmpty
                ? 'No events this month.'
                : '${busy.values.fold(0, (a, b) => a + b)} events across '
                      '${busy.length} ${busy.length == 1 ? "day" : "days"}.',
            style: TextStyle(color: p.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= daysInMonth; d++)
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: busy.containsKey(d)
                        ? p.accent.withValues(alpha: 0.16)
                        : p.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: _isToday(DateTime(_anchor.year, _anchor.month, d))
                        ? Border.all(color: p.accent)
                        : null,
                  ),
                  child: Text(
                    '$d',
                    style: TextStyle(
                      color: busy.containsKey(d) ? p.accent : p.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButtons(Duration step) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _anchor = _anchor.subtract(step)),
          icon: Icon(Icons.chevron_left, size: 18, color: p.textSecondary),
        ),
        TextButton(
          onPressed: () => setState(() => _anchor = DateTime.now()),
          child: const Text('Today'),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _anchor = _anchor.add(step)),
          icon: Icon(Icons.chevron_right, size: 18, color: p.textSecondary),
        ),
      ],
    );
  }

  Future<void> _addEvent() async {
    final created = await showDialog<ScheduleEvent>(
      context: context,
      builder: (_) => _AddEventDialog(day: _anchor),
    );
    if (created != null) await scheduleStore.add(created);
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _fullDate(DateTime d) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[d.weekday - 1]} ${d.day} ${_monthName(d.month)}';
  }

  static String _shortDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]} ${d.day} ${_monthName(d.month).substring(0, 3)}';
  }

  static String _monthName(int m) => const [
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
  ][m - 1];
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.live,
    required this.onDelete,
  });

  final ScheduleEvent event;
  final bool live;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: live ? Border.all(color: p.accent) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              '${formatClock(event.start)} – ${formatClock(event.end)}',
              style: TextStyle(color: p.textSecondary, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.notes != null && event.notes!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.notes!,
                    style: TextStyle(color: p.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          StatusChip(
            label: event.category.label.toUpperCase(),
            color: p.accent,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            onPressed: onDelete,
            icon: Icon(Icons.close, size: 16, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AddEventDialog extends StatefulWidget {
  const _AddEventDialog({required this.day});

  final DateTime day;

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  EventCategory _category = EventCategory.personal;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
      title: const Text('New event'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _timeField(context, 'Start', _start, true)),
                const SizedBox(width: 12),
                Expanded(child: _timeField(context, 'End', _end, false)),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<EventCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              dropdownColor: p.surfaceRaised,
              items: [
                for (final c in EventCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }

  Widget _timeField(
    BuildContext context,
    String label,
    TimeOfDay value,
    bool isStart,
  ) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
        );
        if (picked == null) return;
        setState(() {
          if (isStart) {
            _start = picked;
          } else {
            _end = picked;
          }
        });
      },
      child: Text(
        '$label  ${value.hour.toString().padLeft(2, "0")}:'
        '${value.minute.toString().padLeft(2, "0")}',
      ),
    );
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    final day = widget.day;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      _start.hour,
      _start.minute,
    );
    var end = DateTime(day.year, day.month, day.day, _end.hour, _end.minute);
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));

    Navigator.pop(
      context,
      ScheduleEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        start: start,
        end: end,
        category: _category,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }
}
