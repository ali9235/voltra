import 'package:flutter/material.dart';

import '../context_engine/context_state.dart';

/// The VOLTRA colour set for one context.
///
/// This is a shift in mood, not a change of identity: the same layout, the same
/// density, the same wordmark. Day, evening and night stay dark and
/// cyan-rooted; a workout raises the accent; MORNING is the one that genuinely
/// changes the light, because waking up should not look like 2am. Nothing
/// animates beyond a slow cross-fade, nothing flashes.
@immutable
class VoltraPalette extends ThemeExtension<VoltraPalette> {
  final String name;

  /// Light or dark. The only palette that is light is [morning]; everything
  /// that reads a colour reads it from this class, so the whole app follows.
  final Brightness brightness;

  final Color background;

  /// Two or three stops painted behind the whole shell. Morning uses it for a
  /// real sunrise wash; the dark palettes leave it null and stay flat.
  final List<Color>? backgroundGradient;

  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color positive;
  final Color warning;
  final Color danger;

  const VoltraPalette({
    required this.name,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.positive,
    required this.warning,
    required this.danger,
    this.brightness = Brightness.dark,
    this.backgroundGradient,
  });

  /// What to draw on top of [accent] — a filled button's label, for instance.
  Color get onAccent =>
      brightness == Brightness.light ? const Color(0xFFFFFFFF) : background;

  bool get isLight => brightness == Brightness.light;

  static const Color _positive = Color(0xFF5BE3A7);
  static const Color _warning = Color(0xFFF2C14E);
  static const Color _danger = Color(0xFFF2685C);

  /// The original VOLTRA look. Everything else is a variation on it.
  static const VoltraPalette day = VoltraPalette(
    name: 'DAY',
    background: Color(0xFF090B10),
    surface: Color(0xFF12151C),
    surfaceRaised: Color(0xFF181C25),
    border: Color(0xFF232833),
    accent: Color(0xFF3BE0F0),
    textPrimary: Color(0xFFF2F5F9),
    textSecondary: Color(0xFF9BA6B6),
    textMuted: Color(0xFF5E6878),
    positive: _positive,
    warning: _warning,
    danger: _danger,
  );

  /// MORNING MODE. Bright and alive on purpose — this is the one context where
  /// VOLTRA is meant to feel like the lights just came on. Dark text on a warm
  /// sunrise wash, with the accents pulled darker so they still read against
  /// white instead of glowing.
  static const VoltraPalette morning = VoltraPalette(
    name: 'MORNING',
    brightness: Brightness.light,
    background: Color(0xFFF6FAFD),
    backgroundGradient: <Color>[
      Color(0xFFFFF6E9), // low sun
      Color(0xFFF7FBFE), // daylight
      Color(0xFFEFF6FC), // cool sky
    ],
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF0F6FB),
    border: Color(0xFFDDE7F0),
    accent: Color(0xFF0E8F9E),
    textPrimary: Color(0xFF0D1A22),
    textSecondary: Color(0xFF47606E),
    textMuted: Color(0xFF7C8FA0),
    positive: Color(0xFF12855C),
    warning: Color(0xFFA8700A),
    danger: Color(0xFFBE3A2D),
  );

  static const VoltraPalette evening = VoltraPalette(
    name: 'EVENING',
    background: Color(0xFF0D0A0B),
    surface: Color(0xFF181315),
    surfaceRaised: Color(0xFF211A1B),
    border: Color(0xFF2E2426),
    accent: Color(0xFFFFA26B),
    textPrimary: Color(0xFFF7F1EE),
    textSecondary: Color(0xFFB3A39C),
    textMuted: Color(0xFF6E605B),
    positive: _positive,
    warning: _warning,
    danger: _danger,
  );

  static const VoltraPalette night = VoltraPalette(
    name: 'NIGHT',
    background: Color(0xFF05060A),
    surface: Color(0xFF0C0F16),
    surfaceRaised: Color(0xFF12161F),
    border: Color(0xFF1A1F2A),
    accent: Color(0xFF6E86E8),
    textPrimary: Color(0xFFDDE3EC),
    textSecondary: Color(0xFF808C9E),
    textMuted: Color(0xFF4C5666),
    positive: _positive,
    warning: _warning,
    danger: _danger,
  );

  /// Higher energy. Used only while a session is actually running.
  static const VoltraPalette workout = VoltraPalette(
    name: 'WORKOUT',
    background: Color(0xFF0B0709),
    surface: Color(0xFF171013),
    surfaceRaised: Color(0xFF20161A),
    border: Color(0xFF32222A),
    accent: Color(0xFFFF5C7A),
    textPrimary: Color(0xFFFBF2F4),
    textSecondary: Color(0xFFB9A2A9),
    textMuted: Color(0xFF725C63),
    positive: _positive,
    warning: _warning,
    danger: _danger,
  );

  /// Restorative. Used after a session and on recovery days.
  static const VoltraPalette recovery = VoltraPalette(
    name: 'RECOVERY',
    background: Color(0xFF070C0A),
    surface: Color(0xFF101815),
    surfaceRaised: Color(0xFF16211D),
    border: Color(0xFF1F2E28),
    accent: Color(0xFF63D6A4),
    textPrimary: Color(0xFFEFF6F2),
    textSecondary: Color(0xFF97AAA2),
    textMuted: Color(0xFF5B6B64),
    positive: _positive,
    warning: _warning,
    danger: _danger,
  );

  /// Picks the palette for a context. Activity wins over time of day only
  /// where it genuinely changes what the screen is for.
  static VoltraPalette forContext(ContextSnapshot context) {
    switch (context.activity) {
      case ActivityPhase.workout:
        return workout;
      case ActivityPhase.postWorkout:
      case ActivityPhase.recovery:
        return recovery;
      case ActivityPhase.postSleep:
        // Morning Mode follows the WAKE, not the clock. Ali waking at 11:02
        // gets the bright palette; so does Ali waking at 13:30 after a late
        // night. The measured sleep-end is what decides, which is the whole
        // point of deriving this from real data.
        return morning;
      case ActivityPhase.preWorkout:
      case ActivityPhase.restDay:
        break;
    }

    return switch (context.phase) {
      DayPhase.morning => morning,
      DayPhase.day => day,
      DayPhase.evening => evening,
      DayPhase.night => night,
    };
  }

  @override
  VoltraPalette copyWith({
    String? name,
    Brightness? brightness,
    List<Color>? backgroundGradient,
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? positive,
    Color? warning,
    Color? danger,
  }) {
    return VoltraPalette(
      name: name ?? this.name,
      brightness: brightness ?? this.brightness,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  VoltraPalette lerp(ThemeExtension<VoltraPalette>? other, double t) {
    if (other is! VoltraPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t) ?? a;

    // Gradients are blended stop by stop. When one side has none, its flat
    // background stands in for every stop so the wash fades in rather than
    // appearing all at once.
    List<Color>? gradient() {
      final from = backgroundGradient;
      final to = other.backgroundGradient;
      if (from == null && to == null) return null;
      final length = (from?.length ?? 0) > (to?.length ?? 0)
          ? from!.length
          : to!.length;
      return <Color>[
        for (var i = 0; i < length; i++)
          c(
            from == null ? background : from[i.clamp(0, from.length - 1)],
            to == null ? other.background : to[i.clamp(0, to.length - 1)],
          ),
      ];
    }

    return VoltraPalette(
      name: t < 0.5 ? name : other.name,
      brightness: t < 0.5 ? brightness : other.brightness,
      backgroundGradient: gradient(),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      border: c(border, other.border),
      accent: c(accent, other.accent),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      positive: c(positive, other.positive),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
    );
  }
}

extension VoltraPaletteOf on BuildContext {
  /// The palette for the current context. Falls back to the original VOLTRA
  /// colours if the extension is somehow missing.
  VoltraPalette get palette =>
      Theme.of(this).extension<VoltraPalette>() ?? VoltraPalette.day;
}
