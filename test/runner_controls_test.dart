import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_game/main.dart';

void main() {
  testWidgets(
    '320x568 keeps start and both real controls visible without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      expect(tester.getRect(find.text('开始跑酷')).bottom, lessThanOrEqualTo(568));
      await tester.tap(find.text('开始跑酷'));
      await tester.pump();
      expect(tester.getRect(find.text('跳跃')).bottom, lessThanOrEqualTo(568));
      expect(tester.getRect(find.text('按住滑行')).bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'semantic slide activation can be released and has one real button',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const MyApp());
        await tester.pump();
        await tester.tap(find.text('开始跑酷'));
        await tester.pump();
        final button = find.widgetWithText(OutlinedButton, '按住滑行');
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          tester.getSemantics(button).id,
          SemanticsAction.tap,
        );
        await tester.pump();
        expect(find.text('松开滑行'), findsOneWidget);
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          tester.getSemantics(find.widgetWithText(OutlinedButton, '松开滑行')).id,
          SemanticsAction.tap,
        );
        await tester.pump();
        expect(find.text('按住滑行'), findsOneWidget);
        expect(find.text('松开滑行'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        semantics.dispose();
      }
    },
  );
}
