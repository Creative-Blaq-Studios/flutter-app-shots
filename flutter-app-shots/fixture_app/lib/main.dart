import 'package:flutter/material.dart';

void main() => runApp(const FixtureApp());

ThemeData fixtureTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6750A4),
      fontFamily: 'Roboto',
    );

class Note {
  final String title;
  final String body;
  final Color color;
  const Note(this.title, this.body, this.color);
}

const kSampleNotes = [
  Note('Ship the launch plan', 'Marketing sync at 10 — bring the roadmap.',
      Color(0xFF6750A4)),
  Note('Grocery run', 'Oat milk, basil, coffee beans, dark chocolate.',
      Color(0xFF7D5260)),
  Note('Piano practice', 'Nocturne op. 9 no. 2 — slow left hand first.',
      Color(0xFF625B71)),
  Note('Weekend hike', 'Trailhead at 8am. Pack the good camera.',
      Color(0xFF2E7D32)),
  Note('Read: Designing Data', 'Chapter 4 — encoding and evolution.',
      Color(0xFF1565C0)),
];

const kSampleStats = {'Mon': 3, 'Tue': 5, 'Wed': 2, 'Thu': 7, 'Fri': 4};

class FixtureApp extends StatelessWidget {
  const FixtureApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Fixture Notes',
        theme: fixtureTheme(),
        home: const HomeScreen(notes: kSampleNotes),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: notes.length,
        itemBuilder: (context, i) {
          final note = notes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: note.color,
                child: Text(note.title[0],
                    style: const TextStyle(color: Colors.white)),
              ),
              title: Text(note.title),
              subtitle: Text(note.body),
            ),
          );
        },
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final maxCount =
        counts.values.reduce((a, b) => a > b ? a : b).toDouble();
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6750A4), Color(0xFF9A82DB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This week',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text('21 notes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in counts.entries)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 36,
                          height: 60 + 140 * (e.value / maxCount),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6750A4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(e.key),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
