import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cuentas_claras_app/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CuentasClarasApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
