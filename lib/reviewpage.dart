import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:live_project/main.dart';
import 'model page/model_page.dart';

class ReviewListPage extends StatefulWidget {
  const ReviewListPage({super.key});

  @override
  State<ReviewListPage> createState() => _ReviewListPageState();
}

class _ReviewListPageState extends State<ReviewListPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (mounted) setState(() => _currentlyPlayingId = null);
      }
    });
  }

  void _playAudio(String path, String id) async {
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file not found or deleted')),
        );
      }
      return;
    }

    if (_currentlyPlayingId == id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _currentlyPlayingId = id);
    }
  }

  void _deleteRecording(Recording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Are you sure you want to delete "${recording.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (_currentlyPlayingId == recording.id) {
          await _audioPlayer.stop();
          setState(() => _currentlyPlayingId = null);
        }

        final file = File(recording.audioPath);
        if (await file.exists()) {
          await file.delete();
        }

        await recording.delete();

        if (mounted) {
          Provider.of<AppData>(context, listen: false).notifyListeners();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${recording.word}"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting recording: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _deleteAllRecordings() async {
    final app = Provider.of<AppData>(context, listen: false);
    final allRecordings = app.recordings.toList();

    if (allRecordings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recordings to delete')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Recordings'),
        content: Text(
          'Are you sure you want to delete all ${allRecordings.length} recordings?\n\nThis will also reset your progress and achievements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingId = null);
        await app.resetProgress();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All recordings deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting recordings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppData>(
      builder: (ctx, app, child) {
        final allRecordings = app.recordings.toList();

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(
              'Review Recordings',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              if (allRecordings.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  tooltip: 'Delete All',
                  onPressed: _deleteAllRecordings,
                ),
            ],
          ),
          body: Stack(
            children: [
              // Background image
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/background.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Scrollable content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 70), // 70px space for bottom nav
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Recording Review',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: allRecordings.isEmpty
                              ? const Center(
                            child: Text(
                              'No recordings yet',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16),
                            ),
                          )
                              : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: allRecordings.length,
                              itemBuilder: (context, index) {
                                final r = allRecordings[index];
                                final isPlaying = _currentlyPlayingId == r.id;
                                final isPending = r.status == RecordingStatus.pending;

                                return Card(
                                  color: Colors.white.withOpacity(0.1),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                          color: r.status == RecordingStatus.approved
                                              ? Colors.green
                                              : r.status == RecordingStatus.rejected
                                              ? Colors.red
                                              : Colors.orange)),
                                  child: ListTile(
                                    leading: Icon(
                                      r.status == RecordingStatus.approved
                                          ? Icons.check_circle
                                          : r.status == RecordingStatus.rejected
                                          ? Icons.cancel
                                          : Icons.hourglass_top,
                                      color: r.status == RecordingStatus.approved
                                          ? Colors.green
                                          : r.status == RecordingStatus.rejected
                                          ? Colors.red
                                          : Colors.orange,
                                    ),
                                    title: Text(
                                      r.word,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    subtitle: Text(
                                      'Letter: ${r.letter} - ${r.status.name.toUpperCase()}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: Icon(
                                              isPlaying
                                                  ? Icons.stop_circle_outlined
                                                  : Icons.play_circle_fill,
                                              color: Colors.tealAccent,
                                              size: 32,
                                            ),
                                            onPressed: () =>
                                                _playAudio(r.audioPath, r.id)),
                                        if (isPending) ...[
                                          IconButton(
                                              onPressed: () =>
                                                  app.reviewRecording(r, true),
                                              icon: const Icon(Icons.check_circle,
                                                  color: Colors.green)),
                                          IconButton(
                                              onPressed: () =>
                                                  app.reviewRecording(r, false),
                                              icon: const Icon(Icons.cancel,
                                                  color: Colors.red)),
                                        ],
                                        IconButton(
                                          onPressed: () => _deleteRecording(r),
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.redAccent),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}