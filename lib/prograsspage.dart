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
        // 🔹 Background image
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularPercentIndicator(
                  radius: 110,
                  lineWidth: 20,
                  percent: progress.clamp(0.0, 1.0),
                  progressColor: Colors.teal,
                  backgroundColor: Colors.black12,
                  circularStrokeCap: CircularStrokeCap.round,
                  center: Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "You've learned $approved of $totalWords words",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Keep going! 🎉',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
