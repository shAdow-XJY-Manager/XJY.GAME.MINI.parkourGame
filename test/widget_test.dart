import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_game/main.dart';

void main() {
  testWidgets('runner remains Ready until the player starts the route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    expect(find.text('终端跑酷'), findsOneWidget);
    expect(find.text('路线 1 · 热身'), findsOneWidget);
    await tester.tap(find.text('开始跑酷'));
    await tester.pump();
    expect(find.text('开始跑酷'), findsNothing);
    expect(find.text('路线 1 · 热身'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'real 320x800 at 200 percent text keeps Ready, Playing controls and pause usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final errors = <Object>[];
      void collectErrors() {
        Object? error;
        while ((error = tester.takeException()) != null) {
          errors.add(error!);
        }
      }

      Future<void> frame([Duration duration = Duration.zero]) async {
        await tester.pump(duration);
        collectErrors();
      }

      Future<void> tapVisible(Finder target) async {
        expect(target, findsOneWidget);
        await tester.ensureVisible(target);
        await frame();
        expect(target.hitTestable(), findsOneWidget);
        expect(MediaQuery.textScalerOf(tester.element(target)).scale(14), 28);
        final labels = find.descendant(of: target, matching: find.byType(Text));
        for (var i = 0; i < labels.evaluate().length; i++) {
          _expectFullText(tester, labels.at(i), errors);
        }
        await tester.tap(target.hitTestable());
        await frame();
      }

      try {
        await tester.pumpWidget(_doubleTextApp());
        collectErrors();
        await frame();

        final start = _buttonText('开始跑酷');
        final pause = _buttonText('暂停');
        expect(MediaQuery.sizeOf(tester.element(start)), const Size(320, 800));
        expect(MediaQuery.textScalerOf(tester.element(start)).scale(14), 28);
        expect(tester.widget<OutlinedButton>(pause).onPressed, isNull);
        await frame(const Duration(milliseconds: 100));
        expect(start, findsOneWidget);
        await tapVisible(start);
        expect(find.text('开始跑酷'), findsNothing);
        final jump = _buttonText('跳跃');
        final slide = _buttonText('按住滑行');
        expect(tester.widget<OutlinedButton>(jump).onPressed, isNotNull);
        expect(tester.widget<OutlinedButton>(slide).onPressed, isNotNull);
        await tapVisible(jump);
        await tapVisible(slide);
        await frame(const Duration(milliseconds: 16));
        await tapVisible(pause);
        expect(find.text('跑道已暂停'), findsOneWidget);
        expect(tester.widget<OutlinedButton>(jump).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(slide).onPressed, isNull);
        await tapVisible(_buttonText('继续跑酷'));
        expect(find.text('跑道已暂停'), findsNothing);
        expect(tester.widget<OutlinedButton>(jump).onPressed, isNotNull);
        expect(tester.widget<OutlinedButton>(slide).onPressed, isNotNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        collectErrors();
        await frame();
      }
      expect(
        errors,
        isEmpty,
        reason: errors.map((e) => e.toString()).join('\n\n'),
      );
    },
  );
}

Widget _doubleTextApp() => Builder(
  builder: (context) {
    final app = const MyApp().build(context) as MaterialApp;
    return MaterialApp(
      debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
      title: app.title,
      theme: app.theme,
      home: app.home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: child!,
      ),
    );
  },
);

void _expectFullText(WidgetTester tester, Finder text, List<Object> errors) {
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
  expect(MediaQuery.textScalerOf(tester.element(text)).scale(14), 28);
  expect(paragraph.textScaler.scale(14), 28);
  if (paragraph.size.height + 1 < needed || paragraph.didExceedMaxLines) {
    errors.add(
      FlutterError(
        '${paragraph.text.toPlainText()} needs $needed px but has ${paragraph.size.height} px '
        'at ${MediaQuery.sizeOf(tester.element(text)).width} px viewport; '
        'didExceedMaxLines=${paragraph.didExceedMaxLines}',
      ),
    );
  }
}

Finder _buttonText(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);
