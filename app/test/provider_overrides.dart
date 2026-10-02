// 这些工厂只在测试里拼 ProviderScope，返回类型跟 Riverpod 的 Override 走，不单独声明。
// ignore_for_file: strict_top_level_inference

import 'package:flutter/material.dart';
import 'package:flowdo/models/briefing.dart';
import 'package:flowdo/models/space.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/ui/briefing_clock_button.dart';

/// 测试里塞一份固定的 /me，避免 AsyncNotifier 去打真接口。
class FixedMeController extends MeController {
  FixedMeController(this.me);

  final Me me;

  @override
  Future<Me> build() async => me;
}

meOverride(Me me) => meProvider.overrideWith(() => FixedMeController(me));

class EmptyTasksController extends TasksController {
  EmptyTasksController(super.status);

  @override
  Future<List<Task>> build() async => const [];
}

emptyTasksOverride() => tasksProvider.overrideWith2(EmptyTasksController.new);

class FixedSpacesController extends SpacesController {
  FixedSpacesController(this.spaces);

  final List<Space> spaces;

  @override
  Future<List<Space>> build() async => spaces;
}

spacesOverride(List<Space> spaces) =>
    spacesProvider.overrideWith(() => FixedSpacesController(spaces));

class FixedBriefingController extends BriefingController {
  FixedBriefingController(this.briefing);

  final Briefing briefing;

  @override
  Future<Briefing> build() async => briefing;
}

briefingOverride(Briefing briefing) =>
    briefingProvider.overrideWith(() => FixedBriefingController(briefing));

class FixedWeatherController extends WeatherController {
  FixedWeatherController([this.snap]);

  final WeatherSnapshot? snap;

  @override
  Future<WeatherSnapshot?> build() async =>
      snap ??
      const WeatherSnapshot(
        label: '晴',
        icon: Icons.wb_sunny_rounded,
        minC: 18,
        maxC: 26,
      );
}

weatherOverride([WeatherSnapshot? snap]) =>
    weatherProvider.overrideWith(() => FixedWeatherController(snap));

