import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_game/arcade_game.dart';
import 'package:parkour_game/game_engine.dart';

Future<void> mount(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const MyApp());
  for (var i = 0; i < 100 && find.text('开始跑酷').evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'cancel retry retains paused game and current level selection is a no-op',
    (tester) async {
      await mount(tester, const Size(1280, 1000));
      await tester.tap(find.text('开始跑酷'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      final dynamic state = tester.state(find.byType(RunnerArcade));
      final game = state.game;
      expect(game.status, RunnerStatus.paused);
      final retry = find.text('重新开始路线');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('保留进度'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(identical(state.game, game), isTrue);
      expect(state.game.status, RunnerStatus.paused);
      final currentLevel = find.widgetWithText(OutlinedButton, '路线 1');
      await tester.ensureVisible(currentLevel);
      await tester.tap(currentLevel);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(identical(state.game, game), isTrue);
      final proceed = find.text('继续跑酷');
      await tester.ensureVisible(proceed);
      await tester.tap(proceed);
      await tester.pump();
      expect(state.game.status, RunnerStatus.playing);
      expect(identical(state.game, game), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
