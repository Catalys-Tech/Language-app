// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:live_project/spalsh_screen.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'Static _Data_Page.dart';
import 'main.g.dart';
import 'model page/model_page.dart';

// ==================== MODELS ====================

class Language {
  final String code;
  final String name;
  final List<String> letters;
  final Map<String, List<String>> wordsMap;

  const Language({
    required this.code,
    required this.name,
    required this.letters,
    required this.wordsMap,
  });
}

// ==================== PROVIDERS ====================
class AppData with ChangeNotifier {
  Box<Recording>? _recordingsBox;
  Box? _approvedWordsBox;
  Box? _unlockedAchievementsBox;
  bool _initialized = false;
  bool _justCompletedLetter = false;

  bool get initialized => _initialized;
  bool get justCompletedLetter => _justCompletedLetter;
  List<Recording> get recordings => _recordingsBox?.values.toList() ?? [];

  int getApprovedCount(String code) {
    if (_approvedWordsBox == null) return 0;
    final key = 'approved_$code';
    final list =
    _approvedWordsBox!.get(key, defaultValue: <String>[]) as List<String>;
    return list.length;
  }

  Set<String> getUnlocked(String code) {
    if (_unlockedAchievementsBox == null) return {};
    final key = 'unlocked_$code';
    final list =
    _unlockedAchievementsBox!.get(key, defaultValue: <String>[])
    as List<String>;
    return Set<String>.from(list);
  }

  // 🆕 Check if a word is already approved
  bool isWordAlreadyApproved(String word, String langCode) {
    if (_approvedWordsBox == null) return false;
    final key = 'approved_$langCode';
    final approvedList = List<String>.from(
      _approvedWordsBox!.get(key, defaultValue: <String>[]),
    );
    return approvedList.contains(word);
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0))
        Hive.registerAdapter(RecordingAdapter());
      if (!Hive.isAdapterRegistered(1))
        Hive.registerAdapter(RecordingStatusAdapter());

      if (!Hive.isBoxOpen('recordings')) {
        _recordingsBox = await Hive.openBox<Recording>('recordings');
      }
      if (!Hive.isBoxOpen('approvedWords')) {
        _approvedWordsBox = await Hive.openBox('approvedWords');
      }
      if (!Hive.isBoxOpen('unlockedAchievements')) {
        _unlockedAchievementsBox = await Hive.openBox('unlockedAchievements');
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Hive init error: $e');
      rethrow;
    }
  }

  Future<void> addRecording(
      String word,
      String letter,
      String audioPath,
      String langCode,
      ) async {
    try {
      if (_recordingsBox == null) return;

      // 🔹 Allow all recordings to be added (including duplicates)
      // No checking - just add the recording
      final recording = Recording(
        word: word,
        letter: letter,
        audioPath: audioPath,
        langCode: langCode,
      );
      await _recordingsBox!.add(recording);
      notifyListeners();
    } catch (e) {
      debugPrint('addRecording error: $e');
      rethrow;
    }
  }

  Future<void> reviewRecording(Recording recording, bool isApproved) async {
    try {
      if (_approvedWordsBox == null || _unlockedAchievementsBox == null) return;
      if (recording.status != RecordingStatus.pending) return;

      if (isApproved) {
        // 🔹 Check if word is already approved before adding to progress
        final key = 'approved_${recording.langCode}';
        final approvedList = List<String>.from(
          _approvedWordsBox!.get(key, defaultValue: <String>[]),
        );

        // 🔹 Only add to approved list if not already there (for progress tracking)
        if (!approvedList.contains(recording.word)) {
          approvedList.add(recording.word);
          await _approvedWordsBox!.put(key, approvedList);

          final wasUnlocked = getUnlocked(
            recording.langCode,
          ).contains(recording.letter);
          _checkForAchievement(recording.letter, recording.langCode);
          final nowUnlocked = getUnlocked(
            recording.langCode,
          ).contains(recording.letter);

          if (!wasUnlocked && nowUnlocked) _justCompletedLetter = true;
        } else {
          debugPrint('Word "${recording.word}" was already approved. Not counting duplicate in progress.');
        }

        recording.status = RecordingStatus.approved;
      } else {
        recording.status = RecordingStatus.rejected;
      }

      // 🔹 Just update the status, don't delete anything
      await recording.save();
      notifyListeners();
    } catch (e) {
      debugPrint('reviewRecording error: $e');
      rethrow;
    }
  }

  void _checkForAchievement(String letter, String langCode) {
    final wordMap = getWordsMapForLang(langCode);
    final wordsForLetter = wordMap[letter] ?? [];
    final key = 'approved_$langCode';
    final approvedList = List<String>.from(
      _approvedWordsBox!.get(key, defaultValue: <String>[]),
    );

    final allWordsApproved = wordsForLetter.every((wordData) {
      final word = wordData.split(',').first.trim();
      return approvedList.contains(word);
    });

    final achievementsKey = 'unlocked_$langCode';
    final unlockedList = List<String>.from(
      _unlockedAchievementsBox!.get(achievementsKey, defaultValue: <String>[]),
    );
    final unlockedSet = Set<String>.from(unlockedList);

    if (allWordsApproved && !unlockedSet.contains(letter)) {
      unlockedList.add(letter);
      _unlockedAchievementsBox!.put(achievementsKey, unlockedList);
    }
  }

  Future<void> resetProgress({String? languageCode}) async {
    try {
      debugPrint('🔄 Starting reset for language: ${languageCode ?? "ALL"}');

      if (_recordingsBox != null) {
        // Get all recordings to delete
        final recordingsToDelete = languageCode == null
            ? _recordingsBox!.values.toList()
            : _recordingsBox!.values.where((r) => r.langCode == languageCode).toList();

        debugPrint('📦 Found ${recordingsToDelete.length} recordings to delete');

        // Delete audio files first
        for (final recording in recordingsToDelete) {
          try {
            final file = File(recording.audioPath);
            if (await file.exists()) {
              await file.delete();
              debugPrint('🗑️ Deleted audio: ${recording.audioPath}');
            }
          } catch (e) {
            debugPrint('⚠️ Error deleting file: $e');
          }
        }

        // Delete recordings from box
        for (final recording in recordingsToDelete) {
          await recording.delete();
        }
        debugPrint('✅ Deleted ${recordingsToDelete.length} recordings from box');
      }

      if (_approvedWordsBox != null) {
        if (languageCode == null) {
          await _approvedWordsBox!.clear();
          debugPrint('✅ Cleared all approved words');
        } else {
          final key = 'approved_$languageCode';
          await _approvedWordsBox!.delete(key);
          debugPrint('✅ Cleared approved words for $languageCode');
        }
      }

      if (_unlockedAchievementsBox != null) {
        if (languageCode == null) {
          await _unlockedAchievementsBox!.clear();
          debugPrint('✅ Cleared all achievements');
        } else {
          final key = 'unlocked_$languageCode';
          await _unlockedAchievementsBox!.delete(key);
          debugPrint('✅ Cleared achievements for $languageCode');
        }
      }

      debugPrint('🎉 Reset complete!');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ resetProgress error: $e');
      rethrow;
    }
  }

  void clearCompletionFlag() {
    _justCompletedLetter = false;
    notifyListeners();
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }
}

class LanguageNotifier extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;
  Language get currentLanguage => supportedLanguages[_currentIndex];
  bool get isArabic => currentLanguage.code == 'ar';

  void setLanguage(int index) {
    if (index != _currentIndex) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
// ==================== MAIN ====================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppData()..init()),
        ChangeNotifierProvider(create: (_) => LanguageNotifier()),
      ],
      child: const LanguageApp(),
    ),
  );
}

class LanguageApp extends StatelessWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Learning Adventure',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== LETTERS GRID ====================

class LettersGrid extends StatelessWidget {
  final Language language;

  const LettersGrid({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👇 This makes body content appear *behind* the transparent AppBar
      extendBodyBehindAppBar: true,
      body: Container(
        // 👇 Background image added
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          top: false, // so it flows under AppBar
          child: GridView.builder(
            padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: language.letters.length + 1, // +1 for reset button
            itemBuilder: (context, index) {
              if (index == language.letters.length) {
                return const _ResetTile();
              }
              return LetterTile(
                letter: language.letters[index],
                index: index,
                language: language,
              );
            },
          ),
        ),
      ),
    );
  }
}

// 🔹 Letter tile widget
class LetterTile extends StatelessWidget {
  final String letter;
  final int index;
  final Language language;

  const LetterTile({
    super.key,
    required this.letter,
    required this.index,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[index % _gradients.length];
    final textDir =
    language.code == 'ar' ? TextDirection.rtl : TextDirection.ltr;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WordPages(
            initialLetterIndex: index,
            language: language,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black38, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              spreadRadius: 1,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 40,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(
                  blurRadius: 6,
                  color: Colors.black45,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            textDirection: textDir,
          ),
        ),
      ),
    );
  }
}

// 🔹 Reset tile widget
class _ResetTile extends StatelessWidget {
  const _ResetTile();

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppData>(context, listen: false);

    return InkWell(
      onTap: () async {
        final selectedLanguage = await showDialog<Language>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset Progress'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: supportedLanguages
                  .map(
                    (lang) => ListTile(
                  title: Text(lang.name),
                  onTap: () => Navigator.pop(ctx, lang),
                ),
              )
                  .toList(),
            ),
          ),
        );

        if (selectedLanguage != null) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirm Reset'),
              content: Text(
                  'Are you sure you want to reset progress for ${selectedLanguage.name}?'),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Reset'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await app.resetProgress(languageCode: selectedLanguage.code);
          }
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white70),
        ),
        child: const Center(
          child: Text(
            'Reset\nProgress',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              shadows: [
                Shadow(
                  blurRadius: 5,
                  color: Colors.black54,
                  offset: Offset(1, 2),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// 🔹 Gradient color sets for letter tiles
const List<List<Color>> _gradients = [
  [Color(0xFF42A5F5), Color(0xFF1976D2)],
  [Color(0xFF66BB6A), Color(0xFF2E7D32)],
  [Color(0xFFFFA726), Color(0xFFF57C00)],
  [Color(0xFFEF5350), Color(0xFFD32F2F)],
  [Color(0xFFAB47BC), Color(0xFF6A1B9A)],
  [Color(0xFF26C6DA), Color(0xFF00838F)],
];
// ==================== WORD PAGES ====================

enum RecordingState { ready, recording, recorded }

class WordPages extends StatefulWidget {
  final int initialLetterIndex;
  final Language language;

  const WordPages({
    super.key,
    required this.initialLetterIndex,
    required this.language,
  });

  @override
  State<WordPages> createState() => _WordPagesState();
}

class _WordPagesState extends State<WordPages> {
  late final PageController _controller;
  late final List<_PageItem> _pages;
  late final FlutterSoundRecorder _recorder;
  late final FlutterTts _tts;

  bool _recorderInitialized = false;
  RecordingState _recordingState = RecordingState.ready;
  String? _currentRecordingPath;
  int _currentPageIndex = 0;

  bool get _isArabic => widget.language.code == 'ar';

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _tts = FlutterTts();
    _buildPages();
    _controller = PageController();
    _controller.addListener(_onPageChanged);
    _initRecorder();
    _initTts();
  }

  void _onPageChanged() {
    if (mounted) {
      setState(() {
        _currentPageIndex = _controller.page?.round() ?? 0;
      });
    }
  }

  void _buildPages() {
    final letter = widget.language.letters[widget.initialLetterIndex];
    final words = widget.language.wordsMap[letter] ?? [];
    _pages = [
      _PageItem(letter: letter),
      ...words.map((w) => _PageItem(letter: letter, wordData: w)),
    ];
  }

  Future<void> _initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          _showSnackBar('Microphone permission required');
        }
        return;
      }

      await _recorder.openRecorder();
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 200));
      _recorderInitialized = true;
    } catch (e) {
      debugPrint('Recorder init failed: $e');
      if (mounted) _showSnackBar('Recorder initialization failed');
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage(widget.language.code);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Speak failed: $e');
      if (mounted) _showSnackBar('Text-to-speech failed');
    }
  }

  Future<void> _startRecording(String word) async {
    if (!_recorderInitialized) {
      await _initRecorder();
      if (!_recorderInitialized) {
        if (mounted) _showSnackBar('Recorder not ready');
        return;
      }
    }

    try {
      _currentRecordingPath = await Recording.getUniqueAudioPath(word);
      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacMP4,
      );
      setState(() => _recordingState = RecordingState.recording);
    } catch (e) {
      debugPrint('Start recording failed: $e');
      if (mounted) _showSnackBar('Recording failed to start');
      setState(() => _recordingState = RecordingState.ready);
    }
  }

  Future<void> _stopRecording() async {
    if (_recordingState != RecordingState.recording) return;

    try {
      final path = await _recorder.stopRecorder();
      if (path != null && path.isNotEmpty) {
        setState(() => _recordingState = RecordingState.recorded);
      } else {
        if (mounted) _showSnackBar('Recording failed to save');
        _cancelRecording();
      }
    } catch (e) {
      debugPrint('Stop recording failed: $e');
      if (mounted) _showSnackBar('Failed to stop recording');
      _cancelRecording();
    }
  }

  Future<void> _confirmRecording(String word, String letter) async {
    if (_currentRecordingPath == null) return;

    try {
      final langCode = context.read<LanguageNotifier>().currentLanguage.code;
      await context.read<AppData>().addRecording(
        word,
        letter,
        _currentRecordingPath!,
        langCode,
      );

      if (mounted) {
        _showSnackBar('Recording submitted! 👍');
        setState(() {
          _recordingState = RecordingState.ready;
          _currentRecordingPath = null;
        });

        final isLastPage = _currentPageIndex >= _pages.length - 1;
        await Future.delayed(const Duration(milliseconds: 250));

        if (mounted) {
          if (isLastPage) {
            // Navigate back to homepage (pop all routes until first route)
            Navigator.popUntil(context, (route) => route.isFirst);
          } else {
            _controller.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to submit recording');
    }
  }
  void _cancelRecording() {
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (file.existsSync()) file.deleteSync();
      } catch (e) {
        debugPrint('Failed to delete cancelled recording: $e');
      }
    }
    setState(() {
      _recordingState = RecordingState.ready;
      _currentRecordingPath = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover, // makes it fill the whole screen
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) =>
                          _buildPage(_pages[index]),
                    ),
                  ),
                  _buildNavigationBar(),
                ],
              ),
            ),
            _buildCloseButton(),
            if (_pages[_currentPageIndex].wordData != null)
              _buildRecordingControls(
                _pages[_currentPageIndex].wordData!.split(',').first.trim(),
                _pages[_currentPageIndex].letter,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_PageItem page) {
    final textDir = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    if (page.wordData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              page.letter,
              textDirection: textDir,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 180,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height:30),
            IconButton(
              icon: const Icon(Icons.volume_up, size: 40, color: Colors.black),
              onPressed: () => _speak(page.letter),
            ),
          ],
        ),
      );
    }

    final parts = page.wordData!.split(',');
    final word = parts[0].trim();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Text(
            page.letter,
            textDirection: textDir,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w600,fontSize: 100
            ),
          ),
        ),
        const SizedBox(height: 30),
        Center(
          child: Text(
            word,
            textDirection: textDir,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 50),
        IconButton(
          icon: const Icon(Icons.volume_up, size: 56, color: Colors.black87),
          onPressed: () => _speak(word),
        ),
        if (_isArabic && parts.length > 2)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Text(
                  parts[1].trim(),
                  style: const TextStyle(fontSize: 20, color: Colors.black),
                ),
                Text(
                  parts[2].trim(),
                  style: const TextStyle(fontSize: 20, color: Colors.black87),
                ),
              ],
            ),
          ),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _buildNavigationBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 36,
              color: Colors.white,
            ),
            onPressed: () => _controller.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home, size: 36, color: Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              size: 36,
              color: Colors.black38,
            ),
            onPressed: () => _controller.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 40,
      right: 10,
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.black, size: 30),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildRecordingControls(String word, String letter) {
    switch (_recordingState) {
      case RecordingState.recorded:
        return Positioned(
          bottom: 200,
          left: 100,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Review Recording',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RecordingButton(
                      icon: Icons.check,
                      color: Colors.green,
                      onPressed: () => _confirmRecording(word, letter),
                    ),
                    const SizedBox(width: 16),
                    _RecordingButton(
                      icon: Icons.close,
                      color: Colors.redAccent,
                      onPressed: _cancelRecording,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case RecordingState.recording:
      case RecordingState.ready:
        return Stack(
          children: [
            Positioned(
              bottom: 120,
              right: 30,
              child: GestureDetector(
                onTap: () {
                  if (_recordingState == RecordingState.recording) {
                    _stopRecording();
                  } else {
                    _startRecording(word);
                  }
                },
                onLongPressStart: (_) => _startRecording(word),
                onLongPressEnd: (_) => _stopRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recordingState == RecordingState.recording
                        ? Colors.redAccent
                        : Colors.white,
                    boxShadow: [
                      if (_recordingState == RecordingState.recording)
                        const BoxShadow(
                          color: Colors.red,
                          blurRadius: 24,
                          spreadRadius: 6,
                        )
                      else
                        BoxShadow(
                          color: Colors.grey,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Icon(
                    _recordingState == RecordingState.recording
                        ? Icons.stop_rounded
                        : Icons.mic,
                    size: 36,
                    color: _recordingState == RecordingState.recording
                        ? Colors.white
                        : Colors.teal,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 200,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _recordingState == RecordingState.recording
                      ? 'Recording...'
                      : 'Tap to Record',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.closeRecorder();
    _tts.stop();
    super.dispose();
  }
}

class _RecordingButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RecordingButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _PageItem {
  final String letter;
  final String? wordData;

  _PageItem({required this.letter, this.wordData});
}
