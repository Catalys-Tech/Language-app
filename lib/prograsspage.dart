import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import 'main.dart';

class ProgressPage extends StatelessWidget {
  final Language language;
  const ProgressPage({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppData>(context);
    final map = language.wordsMap;
    final totalWords = map.values.fold<int>(0, (p, e) => p + e.length);
    final approved = app.getApprovedCount(language.code);
    final progress = totalWords > 0 ? (approved / totalWords) : 0.0;

    return Scaffold(
      body: Container(
        // 👇 Add background image here
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover, // fills the screen
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularPercentIndicator(
                radius: 110,
                lineWidth: 20,
                percent: progress,
                progressColor: Colors.blueAccent,
                backgroundColor: Colors.black,
                center: Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // for visibility
                  ),
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    "You've learned $approved of $totalWords words",
                    style: const TextStyle(fontSize: 16, color: Colors.black38),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Keep going! 🎉',
                style: TextStyle(fontSize: 16, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
