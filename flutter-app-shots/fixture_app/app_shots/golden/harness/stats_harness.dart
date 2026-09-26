// Harness for shot "stats" — fixture fill: StatsScreen over the gradient
// header, light status bar for contrast.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixture_app/main.dart';
import '../status_bar.dart';

final ShotStatusBarStyle statusBarStyle = ShotStatusBarStyle.light;

ThemeData buildTheme() => fixtureTheme();

Widget buildShot() => const StatsScreen(counts: kSampleStats);

Future<void> preCapture(WidgetTester tester) async {}
