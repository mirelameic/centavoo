import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/widgets/logo.dart';
import 'package:centavoo/theme.dart';

const _brandBackground = Color(0xFF1A1815);
const _brandCream = Color(0xFFFFF3E0);

Future<void> _loadFonts() async {
  final loader = FontLoader('Unbounded')
    ..addFont(rootBundle.load('assets/fonts/Unbounded-Variable.ttf'));
  await loader.load();
}

Future<void> _capture(WidgetTester tester, Widget child, Size viewSize, String path) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        color: Colors.transparent,
        child: Center(child: RepaintBoundary(key: key, child: child)),
      ),
    ),
  );
  await tester.pump();

  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory(path).parent.createSync(recursive: true);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('logo mark, transparent, filling ~74% of a 1024 canvas (app icon foreground)', (tester) async {
    await _capture(
      tester,
      const Logo(size: 760),
      const Size(1024, 1024),
      'assets/icon/icon_foreground.png',
    );
  });

  testWidgets('logo mark on the brand background (flat/legacy/iOS icon)', (tester) async {
    await _capture(
      tester,
      Container(
        width: 1024,
        height: 1024,
        color: _brandBackground,
        alignment: Alignment.center,
        child: const Logo(size: 760),
      ),
      const Size(1024, 1024),
      'assets/icon/icon.png',
    );
  });

  testWidgets('logo mark matching the official Android 12+ splash icon spec (2/3 safe circle, scaled up 5/3x for high-DPI)', (tester) async {
    await _capture(
      tester,
      const Logo(size: 1280),
      const Size(1920, 1920),
      'assets/icon/icon_android12.png',
    );
  });

  testWidgets('logo + wordmark, transparent (splash screen branding)', (tester) async {
    await _loadFonts();
    await _capture(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Logo(size: 220),
          const SizedBox(height: 32),
          Text(
            'CENTAVOO',
            style: unboundedStyle(weight: FontWeight.w700, letterSpacing: 3, color: _brandCream).copyWith(fontSize: 40, height: 1.3),
          ),
          const SizedBox(height: 12),
        ],
      ),
      const Size(700, 500),
      'assets/icon/splash_branding.png',
    );
  });
}
