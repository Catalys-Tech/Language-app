// ------------------------- Home with Bottom Navigation ------------------------

import 'package:flutter/material.dart';
import 'package:live_project/prograsspage.dart';
import 'package:live_project/reviewpage.dart' hide ProgressPage;
import 'package:provider/provider.dart';

import 'Static _Data_Page.dart';
import 'awards.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer2<LanguageNotifier, AppData>(
      builder: (ctx, language, appData, child) {
        final screens = [
          LettersGrid(language: language.currentLanguage),
          ProgressPage(language: language.currentLanguage),
          AchievementsPage(language: language.currentLanguage),
          const ReviewListPage(),
        ];
        final titles = ['Letters', 'Progress', 'Awards', 'Review'];

        if (appData.justCompletedLetter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appData.clearCompletionFlag();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Letter completed! 🎉')),
              );
            }
          });
        }

        return Scaffold(
          extendBody: true, // 👈 allows transparency behind bottom bar and AppBar
          extendBodyBehindAppBar: true, // 👈 makes AppBar float over background
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: AppBar(
              title: Text(
                titles[_selectedIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent, // fully transparent
              elevation: 0,
              scrolledUnderElevation: 0, // prevent scroll tint
              surfaceTintColor: Colors.transparent, // disable Material 3 overlay
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                // Optional slight tint for readability on bright backgrounds:
                // color: Colors.black.withOpacity(0.2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              actions: [
                // 🌐 Change language button
                IconButton(
                  icon: const Icon(Icons.language, color: Colors.white),
                  tooltip: 'Change Language',
                  onPressed: () => _showLanguageSelector(context, language),
                ),

                // 🔄 Reset progress button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Reset Progress',
                  onPressed: () async {
                    final app = Provider.of<AppData>(context, listen: false);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Reset'),
                        content: Text(
                            'Are you sure you want to reset progress for ${language.currentLanguage.name}?'),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Reset'),
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await app.resetProgress(languageCode: language.currentLanguage.code);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Progress reset successfully!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ],

            ),
          ),
          body: screens[_selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1), // 👈 transparent background
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                currentIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
                selectedItemColor: Colors.tealAccent,
                unselectedItemColor: Colors.white70,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.grid_view), label: 'Letters'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.show_chart), label: 'Progress'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.star), label: 'Awards'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.check_circle), label: 'Review'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSelector(BuildContext context, LanguageNotifier language) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      builder: (BuildContext ctx) => SizedBox(
        height: 200,
        child: ListView.builder(
          itemCount: supportedLanguages.length,
          itemBuilder: (ctx2, i) {
            final lang = supportedLanguages[i];
            return ListTile(
              leading: const Icon(Icons.language, color: Colors.white),
              title: Text(lang.name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                language.setLanguage(i);
              },
            );
          },
        ),
      ),
    );
  }
}