import 'dart:io';
import 'package:app_shots/src/cli.dart';

void main(List<String> args) async {
  exitCode = await runCli(args);
}
