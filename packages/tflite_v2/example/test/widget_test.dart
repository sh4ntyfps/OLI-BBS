import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('Verify tflite example app loads', (WidgetTester tester) async {
    // Construimos la app (Usamos App() que es la raíz en tu main.dart)
    await tester.pumpWidget(App());

    // Verificamos que el título de la AppBar aparezca
    expect(find.text('tflite example app'), findsOneWidget);
  });
}
