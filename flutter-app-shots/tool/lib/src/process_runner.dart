import 'dart:io';

class ProcessResultData {
  final int exitCode;
  final String stdout;
  final String stderr;
  const ProcessResultData({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

abstract class ProcessRunner {
  Future<ProcessResultData> run(String exe, List<String> args);
}

class RealProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResultData> run(String exe, List<String> args) async {
    final result = await Process.run(exe, args);
    return ProcessResultData(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }
}

class FakeProcessRunner implements ProcessRunner {
  final Map<String, ProcessResultData> responses;
  FakeProcessRunner({required this.responses});

  @override
  Future<ProcessResultData> run(String exe, List<String> args) async {
    final key = '$exe ${args.join(' ')}'.trim();
    final response = responses[key];
    if (response == null) {
      throw StateError('No fake response configured for: "$key"');
    }
    return response;
  }
}
