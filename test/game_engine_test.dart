import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_game/game_engine.dart';

void main() {
  RunnerEngine replay(int fps, int level) {
    final g = RunnerEngine(level: level)..start();
    for (int i = 0; i < fps * 90 && g.status == RunnerStatus.playing; i++) {
      final near = g.obstacles
          .where((o) => o.x + o.width >= g.distance)
          .firstOrNull;
      if (near != null) {
        if (near.overhead)
          g.slide(near.x - g.distance < 100);
        else {
          g.slide(false);
          if (g.grounded && near.x - g.distance < 75) g.jump();
        }
      }
      g.advance(1 / fps);
    }
    return g;
  }

  test('each authored route has a no-damage path at 30 60 and 120Hz', () {
    for (int level = 0; level < 3; level++) {
      final a = replay(30, level),
          b = replay(60, level),
          c = replay(120, level);
      expect(
        a.status,
        RunnerStatus.cleared,
        reason: 'route $level @30Hz: ${a.reason}',
      );
      expect(b.status, RunnerStatus.cleared);
      expect(c.status, RunnerStatus.cleared);
      expect(a.elapsed, closeTo(b.elapsed, 1 / 30));
      expect(b.elapsed, closeTo(c.elapsed, 1 / 60));
    }
  });
  test(
    'fixed time produces same motion and short release changes jump height',
    () {
      final a = RunnerEngine()
            ..start()
            ..jump(),
          b = RunnerEngine()
            ..start()
            ..jump();
      for (int i = 0; i < 15; i++) a.advance(1 / 30);
      for (int i = 0; i < 60; i++) b.advance(1 / 120);
      expect(a.distance, closeTo(b.distance, 1e-8));
      expect(a.offset, closeTo(b.offset, 1e-8));
      final short = RunnerEngine()
        ..start()
        ..jump();
      short.advance(1 / 120);
      short.releaseJump();
      for (int i = 0; i < 59; i++) short.advance(1 / 120);
      expect(short.offset, greaterThan(b.offset));
    },
  );
  test(
    'landing buffer triggers once; pause and long background frame freeze',
    () {
      final g = RunnerEngine()
        ..start()
        ..jump();
      g.advance(.24);
      g.advance(.24);
      g.advance(.20);
      g.jump();
      g.advance(.1);
      expect(g.jumps, 2);
      g.pause();
      final before = g.distance;
      g.advance(.1);
      expect(g.distance, before);
      g.resume();
      expect(g.jumpBuffer, 0);
      g.advance(2);
      expect(g.status, RunnerStatus.paused);
      expect(g.distance, before);
    },
  );
  test('pausing below a ceiling never forces an unsafe standing collision', () {
    final g = RunnerEngine(level: 1)..start();
    final ceiling = g.obstacles.firstWhere((o) => o.overhead);
    g.distance = ceiling.x + 5;
    g.sliding = true;
    g.slideHeld = true;
    g.pause();
    g.releaseJump();
    g.resume();
    g.advance(1 / 120);
    expect(g.status, RunnerStatus.playing);
    expect(g.sliding, isTrue);
    expect(g.slideHeld, isFalse);
  });

  test(
    'pause freezes the minimum tap ascent and resumes without consuming its hold budget',
    () {
      final paused = RunnerEngine()
        ..start()
        ..jump()
        ..releaseJump();
      final uninterrupted = RunnerEngine()
        ..start()
        ..jump()
        ..releaseJump();
      paused.advance(.1);
      uninterrupted.advance(.1);
      final age = paused.jumpAge,
          offset = paused.offset,
          velocity = paused.velocity;
      paused.pause();
      paused.advance(.2);
      expect(paused.jumpAge, age);
      expect(paused.offset, offset);
      expect(paused.velocity, velocity);
      paused.resume();
      paused.advance(.1);
      uninterrupted.advance(.1);
      expect(paused.jumpAge, closeTo(uninterrupted.jumpAge, 1e-8));
      expect(paused.offset, closeTo(uninterrupted.offset, 1e-8));
      expect(paused.velocity, closeTo(uninterrupted.velocity, 1e-8));
    },
  );

  test('instant tap has enough lift to clear every basic route obstacle', () {
    for (int level = 0; level < 3; level++) {
      final g = RunnerEngine(level: level)..start();
      for (int i = 0; i < 120 * 90 && g.status == RunnerStatus.playing; i++) {
        final near = g.obstacles
            .where((o) => o.x + o.width >= g.distance)
            .firstOrNull;
        if (near != null) {
          if (near.overhead)
            g.slide(near.x - g.distance < 100);
          else {
            g.slide(false);
            if (g.grounded && near.x - g.distance < 75) {
              g.jump();
              g.releaseJump();
            }
          }
        }
        g.advance(1 / 120);
      }
      expect(
        g.status,
        RunnerStatus.cleared,
        reason: 'instant tap route $level: ${g.reason}',
      );
    }
  });
}
