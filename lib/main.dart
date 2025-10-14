// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState;
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main.g.dart';



// ------------------------- Models -------------------------
@HiveType(typeId: 0)
class Recording extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String word;
  @HiveField(2)
  final String letter;
  @HiveField(3)
  final String audioPath;
  @HiveField(4)
  RecordingStatus status;

  Recording({
    required this.word,
    required this.letter,
    required this.audioPath,
    this.status = RecordingStatus.pending,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

  static Future<String> getUniqueAudioPath(String word) async {
    final directory = await getApplicationSupportDirectory();
    await Directory(directory.path).create(recursive: true);
    final safe = word.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    final fileName = 'rec_${safe}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${directory.path}/$fileName';
  }
}

enum RecordingStatus { pending, approved, rejected }

// ------------------------- App Data Provider -------------------------
class AppData with ChangeNotifier {
  Box<Recording>? _recordingsBox;
  Box? _approvedWordsBox;
  Box? _unlockedAchievementsBox;
  bool _initialized = false;
  bool _justCompletedLetter = false;

  bool get initialized => _initialized;
  bool get justCompletedLetter => _justCompletedLetter;

  List<Recording> get recordings =>
      _recordingsBox?.values.toList() ?? <Recording>[];

  Set<String> get approvedWords =>
      Set<String>.from(_approvedWordsBox?.get('words', defaultValue: <String>[]) ?? <String>[]);

  Set<String> get unlockedAchievements =>
      Set<String>.from(_unlockedAchievementsBox?.get('achievements', defaultValue: <String>[]) ?? <String>[]);

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(RecordingAdapter());
      _recordingsBox = await Hive.openBox<Recording>('recordings');
      _approvedWordsBox = await Hive.openBox('approvedWords');
      _unlockedAchievementsBox = await Hive.openBox('unlockedAchievements');
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Hive init error: $e');
      rethrow;
    }
  }

  Future<void> addRecording(String word, String letter, String audioPath) async {
    try {
      if (_recordingsBox == null) return;
      if (recordings.any((r) => r.word == word && r.status == RecordingStatus.pending)) return;
      final r = Recording(word: word, letter: letter, audioPath: audioPath);
      await _recordingsBox!.add(r);
      notifyListeners();
    } catch (e) {
      debugPrint('addRecording error: $e');
      rethrow;
    }
  }

  Future<void> reviewRecording(Recording recording, bool isApproved, Map<String, List<String>> wordMap) async {
    try {
      if (_approvedWordsBox == null || _unlockedAchievementsBox == null) return;

      if (isApproved) {
        recording.status = RecordingStatus.approved;
        final approvedList = approvedWords.toList()..add(recording.word);
        await _approvedWordsBox!.put('words', approvedList);

        final wasUnlocked = unlockedAchievements.contains(recording.letter);
        _checkForAchievement(recording.letter, wordMap);
        final nowUnlocked = unlockedAchievements.contains(recording.letter);
        if (!wasUnlocked && nowUnlocked) _justCompletedLetter = true;
      } else {
        recording.status = RecordingStatus.rejected;
      }

      final audioFile = File(recording.audioPath);
      if (await audioFile.exists()) {
        try {
          await audioFile.delete();
        } catch (e) {
          debugPrint('Failed deleting audio file: $e');
        }
      }
      await recording.delete();
      notifyListeners();
    } catch (e) {
      debugPrint('reviewRecording error: $e');
      rethrow;
    }
  }

  void _checkForAchievement(String letter, Map<String, List<String>> wordMap) {
    final wordsForLetter = wordMap[letter] ?? [];
    final allWordsApproved = wordsForLetter.every((wordData) {
      final word = wordData.split(',').first.trim();
      return approvedWords.contains(word);
    });

    if (allWordsApproved && !unlockedAchievements.contains(letter)) {
      final achievementsList = unlockedAchievements.toList()..add(letter);
      _unlockedAchievementsBox!.put('achievements', achievementsList);
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

// ------------------------- Language Notifier -------------------------
class LanguageNotifier extends ChangeNotifier {
  bool _isArabic = false;
  bool get isArabic => _isArabic;
  void toggleLanguage() {
    _isArabic = !_isArabic;
    notifyListeners();
  }
}

// ------------------------- Static Data -------------------------
const List<String> arabicLetters = ['ا','ب','ت','ث','ج','ح','خ','د','ذ','ر','ز','س','ش','ص','ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','ه','و','ي'];
const List<String> englishLetters = ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'];

final Map<String, List<String>> wordsMapEnglish = {
  'A': ['Apple','Ant','Airplane','Arm','Arrow'],
  'B': ['Ball','Book','Bird','Box','Boy'],
  // add full dataset as needed
};

final Map<String, List<String>> wordsMapArabic = {
  'ا': ['أَب, Father, Ab','أُمّ, Mother, Umm'],
  'ب': ['بَاب, Door, Baab','بَيْت, House, Bayt'],
  // add full dataset as needed
};

// ------------------------- Main -------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppData()..init()),
      ChangeNotifierProvider(create: (_) => LanguageNotifier()),
    ],
    child: const LanguageApp(),
  ));
}

class LanguageApp extends StatelessWidget {
  const LanguageApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Learning Adventure',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      ),
      home: const SplashScreen(),
    );
  }
}

// ------------------------- Splash -------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.blue.shade300])),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children:[
        const Icon(Icons.auto_stories, size: 92, color: Colors.white),
        const SizedBox(height:12),
        Text('Learning Adventure', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ])),
    ),
  );
}

// ------------------------- Home with Bottom Navigation -------------------------
class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  @override Widget build(BuildContext context) {
    final language = Provider.of<LanguageNotifier>(context);
    final screens = [
      LettersGrid(isArabic: language.isArabic),
      ProgressPage(isArabic: language.isArabic),
      AchievementsPage(isArabic: language.isArabic),
      const ReviewListPage()
    ];
    final titles = ['Letters','Progress','Awards','Review'];

    return Consumer<AppData>(builder: (ctx, appData, child){
      if (appData.justCompletedLetter) {
        WidgetsBinding.instance.addPostFrameCallback((_){
          appData.clearCompletionFlag();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Letter completed! 🎉')));
        });
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]),
          actions:[ IconButton(icon: const Icon(Icons.language), onPressed: ()=> language.toggleLanguage()) ],
        ),
        body: screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (i)=> setState(()=> _selectedIndex = i),
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Letters'),
            BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Progress'),
            BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Awards'),
            BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Review'),
          ],
        ),
      );
    });
  }
}

// ------------------------- Letters Grid -------------------------
class LettersGrid extends StatelessWidget {
  final bool isArabic;
  const LettersGrid({super.key, required this.isArabic});
  @override Widget build(BuildContext context){
    final letters = isArabic ? arabicLetters : englishLetters;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFFDE7), Color(0xFFE3F2FD)])),
      child: SafeArea(child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3, mainAxisSpacing:16, crossAxisSpacing:16),
          itemCount: letters.length,
          itemBuilder: (ctx, idx){
            final letter = letters[idx];
            return LetterTile(letter: letter, index: idx, isArabic: isArabic);
          })),
    );
  }
}

class LetterTile extends StatelessWidget {
  final String letter; final int index; final bool isArabic;
  const LetterTile({super.key, required this.letter, required this.index, required this.isArabic});
  @override Widget build(BuildContext context){
    final colors = [
      [const Color(0xFFFC5C7D), const Color(0xFF6A82FB)],
      [const Color(0xFFFBD786), const Color(0xFFF7797D)],
      [const Color(0xFF84FAB0), const Color(0xFF8FD3F4)],
      [const Color(0xFFFF9A8B), const Color(0xFFFF6A88)]
    ];
    final cp = colors[index % colors.length];
    return InkWell(
      onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> WordPages(initialLetterIndex: index))),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: cp),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black, blurRadius:8, offset: const Offset(0,4))],
        ),
        child: Center(child: Text(letter, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 36), textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr )),
      ),
    );
  }
}

// ------------------------- Word Pages with Recording -------------------------
class WordPages extends StatefulWidget { final int initialLetterIndex; const WordPages({super.key, required this.initialLetterIndex}); @override State<WordPages> createState() => _WordPagesState(); }
class _WordPagesState extends State<WordPages> {
  late PageController _controller;
  late List<_PageItem> _pages;
  bool _isArabic = false;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _recorderInited = false;
  bool _isRecording = false;
  String? _recordingPath;

  final AudioPlayer _player = AudioPlayer();

  @override void initState(){
    super.initState();
    _isArabic = Provider.of<LanguageNotifier>(context, listen:false).isArabic;
    _buildPages();
    _controller = PageController();
    _initRecorder();
    _player.onPlayerComplete.listen((_){
      if (mounted) {}
    });
  }

  Future<void> _initRecorder() async {
    try {
      final micStatus = await Permission.microphone.request();
      final storageStatus = await Permission.storage.request();

      if (micStatus != PermissionStatus.granted || storageStatus != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone/storage permission required to record.')));
        }
        return;
      }

      await _recorder.openRecorder();
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 200));
      _recorderInited = true;
      debugPrint('Recorder initialized');
    } catch (e) {
      debugPrint('Recorder init failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recorder init failed: $e')));
    }
  }

  void _buildPages(){
    final letters = _isArabic ? arabicLetters : englishLetters;
    final map = _isArabic ? wordsMapArabic : wordsMapEnglish;
    final letter = letters[widget.initialLetterIndex];
    final words = map[letter] ?? [];
    _pages = [ _PageItem(letter: letter), ...words.map((w)=> _PageItem(letter: letter, wordData: w)) ];
  }

  Future<void> _toggleRecording(String word, String letter) async {
    if (!_recorderInited) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recorder not initialized')));
      return;
    }

    try {
      if (_isRecording) {
        final path = await _recorder.stopRecorder();
        setState(()=> _isRecording = false);
        debugPrint('Stopped recording. path: $path');
        if (path != null) {
          await Provider.of<AppData>(context, listen:false).addRecording(word, letter, path);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording submitted for review')));
        }
      } else {
        _recordingPath = await Recording.getUniqueAudioPath(word);
        debugPrint('Recording to $_recordingPath');
        await _recorder.startRecorder(
          toFile: _recordingPath,
          codec: Codec.aacMP4, // widely supported
        );
        setState(()=> _isRecording = true);
      }
    } catch (e) {
      debugPrint('Recording failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording failed')));
      setState(()=> _isRecording = false);
    }
  }


  @override Widget build(BuildContext context){
    final textDir = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    return Scaffold(
      appBar: AppBar(title: const Text('Learn the Words')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF84FAB0), Color(0xFF8FD3F4)])),
        child: SafeArea(
          child: Column(children:[
            Expanded(
              child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  itemBuilder: (ctx,i){
                    final p = _pages[i];
                    if (p.wordData == null) {
                      return Center(child: Text(p.letter, textDirection: textDir, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 140)));
                    }
                    final parts = p.wordData!.split(',');
                    final word = parts[0].trim();
                    return Column(mainAxisAlignment: MainAxisAlignment.center, children:[
                      Text(p.letter, textDirection: textDir, style: Theme.of(context).textTheme.displayLarge),
                      const SizedBox(height:20),
                      Text(word, textDirection: textDir, style: Theme.of(context).textTheme.headlineMedium),
                      if (_isArabic && parts.length > 2) Padding(padding: const EdgeInsets.only(top:12.0), child: Column(children:[
                        Text(parts[1].trim(), style: const TextStyle(fontSize:20,color:Colors.white70)),
                        Text(parts[2].trim(), style: const TextStyle(fontSize:20,color:Colors.white54)),
                      ])),
                      const SizedBox(height:30),
                      // glowing record button
                      AnimatedContainer(
                        duration: const Duration(milliseconds:300),
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.redAccent : Colors.orange,
                          boxShadow: [
                            if (_isRecording)
                              BoxShadow(color: Colors.redAccent, blurRadius: 30, spreadRadius:5)
                            else
                              BoxShadow(color: Colors.black, blurRadius:8)
                          ],
                        ),
                        child: IconButton(icon: Icon(_isRecording ? Icons.stop : Icons.mic, size:42, color: Colors.white), onPressed: ()=> _toggleRecording(word, p.letter)),
                      ),
                    ]);
                  }
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              IconButton(icon: const Icon(Icons.arrow_back_ios, size:36,color:Colors.white), onPressed: ()=> _controller.previousPage(duration: const Duration(milliseconds:300), curve: Curves.easeIn)),
              IconButton(icon: const Icon(Icons.home, size:36,color:Colors.white), onPressed: ()=> Navigator.pop(context)),
              IconButton(icon: const Icon(Icons.arrow_forward_ios, size:36,color:Colors.white), onPressed: ()=> _controller.nextPage(duration: const Duration(milliseconds:300), curve: Curves.easeIn)),
            ]))
          ]),
        ),
      ),
    );
  }

  @override void dispose(){
    _controller.dispose();
    try { _recorder.closeRecorder(); } catch (_) {}
    _player.dispose();
    super.dispose();
  }
}

class _PageItem { final String letter; final String? wordData; _PageItem({required this.letter, this.wordData}); }

// ------------------------- Progress Page -------------------------
class ProgressPage extends StatelessWidget {
  final bool isArabic; const ProgressPage({super.key, required this.isArabic});
  @override Widget build(BuildContext context){
    final app = Provider.of<AppData>(context);
    final map = isArabic ? wordsMapArabic : wordsMapEnglish;
    final totalWords = map.values.fold<int>(0,(p,e)=> p+ e.length);
    final approved = app.approvedWords.length;
    final progress = totalWords>0 ? (approved/totalWords) : 0.0;
    return Scaffold(appBar: AppBar(title: const Text('My Progress')), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
      CircularPercentIndicator(radius: 110, lineWidth: 20, percent: progress, center: Text('${(progress*100).toStringAsFixed(1)}%', style: const TextStyle(fontSize:28,fontWeight:FontWeight.bold)), footer: Padding(padding: const EdgeInsets.only(top:12.0), child: Text("You've learned $approved of $totalWords words", style: const TextStyle(fontSize:16)))),
      const SizedBox(height:24),
      const Text('Keep going! 🎉', style: TextStyle(fontSize:16))
    ])));
  }
}

// ------------------------- Achievements -------------------------
class AchievementsPage extends StatelessWidget { final bool isArabic; const AchievementsPage({super.key, required this.isArabic});
@override Widget build(BuildContext context){
  final letters = isArabic ? arabicLetters : englishLetters;
  final unlocked = Provider.of<AppData>(context).unlockedAchievements;
  return Scaffold(appBar: AppBar(title: const Text('My Awards')), body: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,mainAxisSpacing:12,crossAxisSpacing:12), itemCount: letters.length, itemBuilder: (ctx,i){
    final l = letters[i];
    final unlockedFlag = unlocked.contains(l);
    return Container(
        decoration: BoxDecoration(
          color: unlockedFlag ? Colors.amber.shade100 : Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: unlockedFlag ? Colors.amber.shade600 : Colors.grey.shade300, width:2.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(l, style: TextStyle(fontSize:22, fontWeight: FontWeight.bold, color: unlockedFlag ? Colors.amber.shade800 : Colors.grey.shade700)),
          if (unlockedFlag) Padding(padding: const EdgeInsets.only(top:6.0), child: Icon(Icons.star, color: Colors.amber.shade700))
        ])
    );
  }));
}
}

// ------------------------- Review List -------------------------
class ReviewListPage extends StatefulWidget { const ReviewListPage({super.key}); @override State<ReviewListPage> createState() => _ReviewListPageState(); }
class _ReviewListPageState extends State<ReviewListPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override void initState(){
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state){
      // keep UI in sync; this will set to null on completion/stop
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (mounted) setState(()=> _currentlyPlayingId = null);
      }
    });
  }

  void _playAudio(String path, String id) async {
    try {
      if (_currentlyPlayingId == id) {
        await _audioPlayer.stop();
        setState(()=> _currentlyPlayingId = null);
      } else {
        await _audioPlayer.play(DeviceFileSource(path));
        setState(()=> _currentlyPlayingId = id);
      }
    } catch (e) {
      debugPrint('playAudio error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playback failed')));
    }
  }

  @override Widget build(BuildContext context){
    return Consumer2<LanguageNotifier, AppData>(builder: (ctx, lang, app, child){
      final isArabic = lang.isArabic;
      final map = isArabic ? wordsMapArabic : wordsMapEnglish;
      final pending = app.recordings.where((r)=> r.status == RecordingStatus.pending).toList();

      return Scaffold(appBar: AppBar(title: const Text('Review Recordings')), body:
      pending.isEmpty ? const Center(child: Text('No new recordings to review', style: TextStyle(fontSize:16,color:Colors.grey)))
          : ListView.builder(itemCount: pending.length, itemBuilder: (ctx,idx){
        final r = pending[idx];
        final isPlaying = _currentlyPlayingId == r.id;
        return Card(margin: const EdgeInsets.symmetric(horizontal:12, vertical:6), elevation:3, child: ListTile(
          leading: const Icon(Icons.music_note, color: Colors.orange),
          title: Text(r.word, style: const TextStyle(fontSize:18,fontWeight: FontWeight.bold)),
          subtitle: Text('Letter: ${r.letter}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children:[
            IconButton(icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_fill, color: Colors.blue, size:32), onPressed: ()=> _playAudio(r.audioPath, r.id)),
            IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: ()=> app.reviewRecording(r, true, map)),
            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: ()=> app.reviewRecording(r, false, map)),
          ]),
        ));
      })
      );
    });
  }

  @override void dispose(){
    _audioPlayer.dispose();
    super.dispose();
  }
}

// ------------------------- Helper -------------------------
extension StringExt on String { String get safeFileName => replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_'); }
