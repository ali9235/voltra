import 'package:flutter/material.dart';

/// The eight modules of VOLTRA. One product, one navigation list.
enum VoltraModule {
  home,
  health,
  sleep,
  training,
  schedule,
  insights,
  chat,
  settings,
}

extension VoltraModuleInfo on VoltraModule {
  String get label => switch (this) {
    VoltraModule.home => 'Home',
    VoltraModule.health => 'Health',
    VoltraModule.sleep => 'Sleep',
    VoltraModule.training => 'Training',
    VoltraModule.schedule => 'Schedule',
    VoltraModule.insights => 'Insights',
    VoltraModule.chat => 'Chat',
    VoltraModule.settings => 'Settings',
  };

  IconData get icon => switch (this) {
    VoltraModule.home => Icons.dashboard_outlined,
    VoltraModule.health => Icons.favorite_outline,
    VoltraModule.sleep => Icons.bedtime_outlined,
    VoltraModule.training => Icons.fitness_center_outlined,
    VoltraModule.schedule => Icons.calendar_today_outlined,
    VoltraModule.insights => Icons.insights_outlined,
    VoltraModule.chat => Icons.chat_bubble_outline,
    VoltraModule.settings => Icons.settings_outlined,
  };
}
