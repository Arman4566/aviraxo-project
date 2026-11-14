import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galla_pro/core/responsive.dart';

/// Pumps a body with a pinned button at the bottom on many screen sizes and checks nothing overflows.
void main() {
  const sizes = <String, Size>{
    'phone portrait': Size(360, 640),
    'phone landscape': Size(640, 360),
    'small phone, big font': Size(320, 480),
    'tablet portrait': Size(800, 1280),
    'tablet landscape': Size(1280, 800),
    'desktop': Size(1920, 1080),
  };

  for (final e in sizes.entries) {
    testWidgets('ScrollFill has no overflow on ${e.key}', (tester) async {
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScrollFill(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (var i = 0; i < 6; i++) const SizedBox(height: 60, child: Text('row')),
              const Spacer(),
              const SizedBox(height: 54, width: double.infinity, child: ElevatedButton(onPressed: null, child: Text('Save'))),
            ]),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Save'), findsOneWidget);
    });
  }

  testWidgets('rail is used on wide screens and sideways phones only', (tester) async {
    Future<bool> rail(Size s) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1;
      late bool r;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        r = Responsive.useRail(c);
        return const SizedBox();
      })));
      return r;
    }

    addTearDown(tester.view.reset);
    expect(await rail(const Size(360, 640)), false);
    expect(await rail(const Size(640, 360)), true);
    expect(await rail(const Size(800, 1280)), true);
    expect(await rail(const Size(1920, 1080)), true);
  });
}
