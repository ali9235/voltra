import 'package:flutter/material.dart';

import '../../app/voltra_services.dart';
import '../../core/health_format.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/voltra_card.dart';
import 'local_answers.dart';

/// Chat grounded in Ali's own data.
///
/// Answers are produced locally from the health summary and series — there is
/// no cloud model behind this, and it says so. If the data needed to answer a
/// question is missing, it says that too instead of guessing.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];

  static const List<String> _suggestions = [
    'How did I sleep this week?',
    'Should I train hard today?',
    'What is my resting heart rate doing?',
    'How active have I been?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_Message(text, fromUser: true));
      _messages.add(
        _Message(
          LocalAnswers.answer(
            text,
            summary: healthSummary.summary,
            series: healthSummary.series,
            status: healthSummary.status,
            context: contextEngine.snapshot,
          ),
          fromUser: false,
        ),
      );
    });

    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _empty(context)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _bubble(context, _messages[i]),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 22),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask about your sleep, training or activity…',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _send,
                child: const Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Says nothing about history rather than claiming "0 days of it".
  static String _historyClause(int? days) {
    if (days == null || days == 0) return '';
    return ' — plus ${days == 1 ? '1 day' : '$days days'} of daily history';
  }

  Widget _empty(BuildContext context) {
    final p = context.palette;
    final summary = healthSummary.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 12),
      children: [
        Text('Ask VOLTRA', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Answered from the data on this machine. No cloud model, no data '
          'leaving your PC.',
          style: TextStyle(color: p.textSecondary, fontSize: 13.5),
        ),
        const SizedBox(height: 20),
        VoltraCard(
          title: 'What VOLTRA can see right now',
          icon: Icons.visibility_outlined,
          child: summary == null
              ? Text(
                  'Nothing yet — the health server has not returned a summary.',
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                )
              : Text(
                  'Your last recorded night '
                  '(${formatHours(summary.overview.sleep?.totalSleepHours)}), '
                  'heart rate, resting heart rate, HRV, steps, active energy, '
                  'exercise minutes and distance'
                  '${_historyClause(healthSummary.series?.daysWithData)}.',
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Text('TRY ASKING', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final suggestion in _suggestions)
              OutlinedButton(
                onPressed: () => _send(suggestion),
                child: Text(suggestion),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context, _Message message) {
    final p = context.palette;

    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: message.fromUser
              ? p.accent.withValues(alpha: 0.14)
              : p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: message.fromUser ? Colors.transparent : p.border,
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.fromUser ? p.textPrimary : p.textSecondary,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _Message {
  final String text;
  final bool fromUser;

  const _Message(this.text, {required this.fromUser});
}
