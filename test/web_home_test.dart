@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interior_frontend/presentation/home/providers/home_provider.dart';
import 'package:interior_frontend/presentation/home/views/home_view.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('web shows file picker without camera action', (tester) async {
    final pixel = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HomeProvider(),
        child: MaterialApp(home: HomeView(backgroundImage: pixel)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose an image'), findsOneWidget);
    expect(find.text('Take a Photo'), findsNothing);
    expect(find.text('From Gallery'), findsNothing);
  });
}
