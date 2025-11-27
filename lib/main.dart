// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:live_project/spalsh_screen.dart';

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

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RecordingAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RecordingStatusAdapter());
      }

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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          top: false,
          child: GridView.builder(
            padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: language.letters.length, // 👈 removed +1
            itemBuilder: (context, index) {
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

// 🔹 Letter Tile Widget
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
    final textDir = language.code == 'ar' ? TextDirection.rtl : TextDirection.ltr;

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

  RecordingState _recordingState = RecordingState.ready;
  String? _currentRecordingPath;
  bool _recorderInitialized = false;
  int _currentPageIndex = 0;
  bool _loading = true;

  bool get _isArabic => widget.language.code == 'ar';

  @override
  void initState() {
    super.initState();

    // build pages first
    _buildPages();

    // controller after pages exist
    _controller = PageController(initialPage: 0);
    _controller.addListener(_onPageChange);

    _recorder = FlutterSoundRecorder();
    _tts = FlutterTts();

    // initialize recorder and tts (don't block UI)
    _initRecorder().whenComplete(() {
      if (mounted) setState(() {}); // update recorder state
    });
    _initTts().whenComplete(() {
      if (mounted) setState(() {});
    });

    // done loading UI
    _loading = false;
  }

  void _buildPages() {
    final letter = widget.language.letters[widget.initialLetterIndex];
    final words = widget.language.wordsMap[letter] ?? [];
    _pages = [
      _PageItem(letter: letter),
      ...words.map((w) => _PageItem(letter: letter, wordData: w))
    ];
  }

  void _onPageChange() {
    if (!mounted) return;
    setState(() => _currentPageIndex = _controller.page?.round() ?? 0);
  }

  Future<void> _initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        // permission not granted — recorder won't be available
        _recorderInitialized = false;
        return;
      }
      await _recorder.openRecorder();
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 200));
      _recorderInitialized = true;
    } catch (e) {
      debugPrint('Recorder init error: $e');
      _recorderInitialized = false;
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage(widget.language.code);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Speak error: $e');
      if (mounted) _showSnackBar('Unable to speak');
    }
  }

  Future<void> _startRecording(String word) async {
    if (!_recorderInitialized) {
      await _initRecorder();
      if (!_recorderInitialized) {
        if (mounted) _showSnackBar('Microphone permission required');
        return;
      }
    }

    try {
      _currentRecordingPath = await Recording.getUniqueAudioPath(word);
      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacMP4,
      );
      if (mounted) setState(() => _recordingState = RecordingState.recording);
    } catch (e) {
      debugPrint('Start recording failed: $e');
      if (mounted) {
        _showSnackBar('Recording failed to start');
        setState(() => _recordingState = RecordingState.ready);
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_recordingState != RecordingState.recording) return;

    try {
      final path = await _recorder.stopRecorder();
      if (path != null && path.isNotEmpty) {
        if (mounted) setState(() => _recordingState = RecordingState.recorded);
      } else {
        if (mounted) {
          _showSnackBar('Recording failed to save');
          _cancelRecording();
        }
      }
    } catch (e) {
      debugPrint('Stop recording failed: $e');
      if (mounted) {
        _showSnackBar('Failed to stop recording');
        _cancelRecording();
      }
    }
  }

  Future<void> _saveRecording(String word, String letter) async {
    if (_currentRecordingPath == null) return;

    try {
      final langCode = context.read<LanguageNotifier>().currentLanguage.code;
      await context.read<AppData>().addRecording(word, letter, _currentRecordingPath!, langCode);

      if (mounted) {
        _showSnackBar('🎉 Good job! Recording saved.');
        setState(() {
          _recordingState = RecordingState.ready;
          _currentRecordingPath = null;
        });

        final isLast = _currentPageIndex >= (_pages.length - 1);
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;

        if (isLast) {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else {
          _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      }
    } catch (e) {
      debugPrint('Save recording error: $e');
      if (mounted) _showSnackBar('Failed to save recording');
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
    if (mounted) {
      setState(() {
        _recordingState = RecordingState.ready;
        _currentRecordingPath = null;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      backgroundColor: Colors.teal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // safe guard: pages must exist
    if (_loading || _pages.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final page = _pages[_currentPageIndex.clamp(0, _pages.length - 1)];
    final textDir = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // keep your background image (unchanged)
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // slight tint over background for readability
            Container(
              color: Colors.white.withOpacity(0.0),
            ),

            SafeArea(
              child: Column(
                children: [
                  // top close button
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.black, size: 34),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),

                  // the pages
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) => _buildPage(_pages[index], textDir),
                      onPageChanged: (idx) {
                        if (mounted) setState(() => _currentPageIndex = idx);
                      },
                    ),
                  ),

                  // navigation buttons
                  _buildNavButtons(),
                ],
              ),
            ),

            // mic controls only when page has wordData
            if (page.wordData != null)
              _buildMicControls(page.wordData!.split(',').first.trim(), page.letter),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_PageItem page, TextDirection dir) {
    // big letter-only page
    if (page.wordData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              page.letter,
              textDirection: dir,
              style: const TextStyle(fontSize: 180, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 40),
            _actionButton(Icons.volume_up, "Tap to hear", () => _speak(page.letter)),
          ],
        ),
      );
    }

    // word page
    final parts = page.wordData!.split(',');
    final word = parts[0].trim();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(page.letter,
            textDirection: dir,
            style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height:70),
        Text(word,
            textDirection: dir,
            style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 40),
        _actionButton(Icons.volume_up, "Tap to hear", () => _speak(word)),
        if (_isArabic && parts.length > 2)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${parts[1].trim()} (${parts[2].trim()})',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: Colors.black,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: Icon(icon, size: 36, color: Colors.teal),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.black26, fontSize: 14),
        ),
      ],
    );
  }


  Widget _buildMicControls(String word, String letter) {
    switch (_recordingState) {
      case RecordingState.recorded:
        return _buildReviewButtons(word, letter);
      case RecordingState.recording:
      case RecordingState.ready:
      default:
        return _buildMicButton(word);
    }
  }

  Widget _buildMicButton(String word) {
    final isRec = _recordingState == RecordingState.recording;
    return Positioned(
      bottom: 125,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => isRec ? _stopRecording() : _startRecording(word),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRec ? Colors.redAccent : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: isRec ? Colors.redAccent.withOpacity(0.5) : Colors.black26,
                  blurRadius: 18,
                  spreadRadius: isRec ? 6 : 2,
                ),
              ],
            ),
            child: Icon(isRec ? Icons.stop_rounded : Icons.mic, size: 44, color: isRec ? Colors.white : Colors.teal),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewButtons(String word, String letter) {
    return Positioned(
      bottom: 140,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _smallCircle(Icons.check, Colors.green, () => _saveRecording(word, letter)),
          const SizedBox(width: 30),
          _smallCircle(Icons.close, Colors.redAccent, _cancelRecording),
        ],
      ),
    );
  }

  Widget _smallCircle(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: CircleAvatar(
        radius: 34,
        backgroundColor: color,
        child: Icon(icon, size: 28, color: Colors.white),
      ),
    );
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navButton(Icons.arrow_back_ios, () => _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
          _navButton(Icons.home_rounded, () => Navigator.pop(context)),
          _navButton(Icons.arrow_forward_ios, () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white.withOpacity(0.9),
        child: Icon(icon, size: 28, color: Colors.teal),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    try {
      _recorder.closeRecorder();
    } catch (e) {
      debugPrint('Error closing recorder: $e');
    }
    try {
      _tts.stop();
    } catch (e) {
      debugPrint('Error stopping tts: $e');
    }
    super.dispose();
  }
}

class _PageItem {
  final String letter;
  final String? wordData;
  _PageItem({required this.letter, this.wordData});
}
