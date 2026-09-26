// Harness for shot "home" — fixture fill: real HomeScreen + fixed sample data.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixture_app/main.dart';
import '../status_bar.dart';

final ShotStatusBarStyle statusBarStyle = ShotStatusBarStyle.dark;

ThemeData buildTheme() => fixtureTheme();

Widget buildShot() => const HomeScreen(notes: kSampleNotes);

Future<void> preCapture(WidgetTester tester) async {}
