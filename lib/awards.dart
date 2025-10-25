import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';

class AchievementsPage extends StatelessWidget {
  final Language language;
  const AchievementsPage({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    final letters = language.letters;
    final unlocked = Provider.of<AppData>(context).getUnlocked(language.code);

    return Scaffold(
      // 🔹 Make body extend behind the app bar
      extendBodyBehindAppBar: true,
      // 🔹 Add transparent AppBar
      appBar: AppBar(
        title: const Text(
          'Achievements',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 3)
              ]),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        // 🔹 leading (back button) removed and automaticallyImplyLeading set to false
        automaticallyImplyLeading: false,
      ),

      // 🔹 Body container with background image
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        // 🔹 Padding to inset the content container
        child: Padding(
          padding: EdgeInsets.only(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            bottom: 10, // No BottomAppBar, so just a small margin
          ),
          // 🔹 New semi-transparent container for the GridView
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4), // Set transparency
              borderRadius: BorderRadius.circular(15), // Add rounded corners
            ),
            clipBehavior: Clip.antiAlias, // Clip children to border radius
            // 🔹 The original GridView
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: letters.length,
              itemBuilder: (ctx, i) {
                final l = letters[i];
                final unlockedFlag = unlocked.contains(l);
                return Container(
                  decoration: BoxDecoration(
                    color: unlockedFlag
                        ? Colors.amber.shade100.withOpacity(0.8)
                        : Colors.blueGrey.shade50.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: unlockedFlag
                          ? Colors.amber.shade600
                          : Colors.grey.shade300,
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: unlockedFlag
                              ? Colors.amber.shade800
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (unlockedFlag)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Icon(Icons.star, color: Colors.amber.shade700),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}