import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/widgets/mitra_chibi_character.dart';

void main() {
  testWidgets('Mitra Chibi canonical renders at multiple sizes', (WidgetTester tester) async {
    // 160px with Sthira background
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFF2B1D2B),
        ),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Container(
                color: const Color(0xFF2B1D2B), // Sthira background
                padding: const EdgeInsets.all(16),
                child: const MitraChibiCharacter(
                  displaySize: 160,
                  animationParams: MitraAnimationParams(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Wait for frames
    await tester.pumpAndSettle();

    // Match golden
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/mitra_160px.png'),
    );

    // 100px
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF2B1D2B)),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Container(
                color: const Color(0xFF2B1D2B),
                padding: const EdgeInsets.all(16),
                child: const MitraChibiCharacter(displaySize: 100),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/mitra_100px.png'));

    // 80px
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF2B1D2B)),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Container(
                color: const Color(0xFF2B1D2B),
                padding: const EdgeInsets.all(16),
                child: const MitraChibiCharacter(displaySize: 80),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/mitra_80px.png'));

    // 48px
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF2B1D2B)),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Container(
                color: const Color(0xFF2B1D2B),
                padding: const EdgeInsets.all(16),
                child: const MitraChibiCharacter(displaySize: 48),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/mitra_48px.png'));
  });
}
