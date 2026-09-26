class DoctorFacts {
  final bool hasFlutter;
  final bool toolResolved;
  final bool rendererResolved;
  final bool targetAppPubspec;
  final String targetAppPath;
  final bool imageGeneration;

  const DoctorFacts({
    required this.hasFlutter,
    required this.toolResolved,
    required this.rendererResolved,
    required this.targetAppPubspec,
    required this.targetAppPath,
    required this.imageGeneration,
  });
}

class DoctorReport {
  final bool hasFlutter;
  final bool toolResolved;
  final bool rendererResolved;
  final bool targetAppPubspec;
  final String targetAppPath;
  final bool imageGeneration;
  final List<String> notes;

  const DoctorReport({
    required this.hasFlutter,
    required this.toolResolved,
    required this.rendererResolved,
    required this.targetAppPubspec,
    required this.targetAppPath,
    required this.imageGeneration,
    required this.notes,
  });

  bool get readyForGolden =>
      hasFlutter && toolResolved && rendererResolved && targetAppPubspec;

  Map<String, dynamic> toJson() => {
        'flutter': hasFlutter,
        'tool': {'resolved': toolResolved},
        'renderer': {'resolved': rendererResolved},
        'targetApp': {'path': targetAppPath, 'pubspec': targetAppPubspec},
        'imageGeneration': imageGeneration,
        'readyForGolden': readyForGolden,
        'notes': notes,
      };
}

DoctorReport buildDoctorReport(DoctorFacts facts) {
  final notes = <String>[];
  if (!facts.hasFlutter) {
    notes.add('flutter not found - golden capture and renderer unavailable');
  }
  if (!facts.toolResolved) {
    notes.add('tool packages unresolved - run `dart pub get` in tool/');
  }
  if (!facts.rendererResolved) {
    notes.add(
        'renderer packages unresolved - run `flutter pub get` in renderer/');
  }
  if (!facts.targetAppPubspec) {
    notes.add('target app pubspec not found at ${facts.targetAppPath}');
  }
  if (!facts.imageGeneration) {
    notes.add('no image-generation capability - CSS backgrounds will be used');
  }

  return DoctorReport(
    hasFlutter: facts.hasFlutter,
    toolResolved: facts.toolResolved,
    rendererResolved: facts.rendererResolved,
    targetAppPubspec: facts.targetAppPubspec,
    targetAppPath: facts.targetAppPath,
    imageGeneration: facts.imageGeneration,
    notes: notes,
  );
}
