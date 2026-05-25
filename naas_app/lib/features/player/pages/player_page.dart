import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/course_model.dart';

class PlayerPage extends StatefulWidget {
  final LessonModel lesson;
  const PlayerPage({super.key, required this.lesson});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final ApiClient _api = ApiClient();
  bool _isPlaying = false;
  int _progressSeconds = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isPlaying) {
        _progressSeconds += 30;
        try {
          await _api.put('/progress/${widget.lesson.id}', data: {
            'progress_seconds': _progressSeconds,
            'total_seconds': widget.lesson.videoDuration ?? 0,
            'completed': _progressSeconds >= (widget.lesson.videoDuration ?? 0) ? 1 : 0,
          });
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Column(
        children: [
          // Video / PDF / Article area
          Expanded(
            child: lesson.type == 'video'
                ? _buildVideoPlayer(lesson)
                : lesson.type == 'pdf'
                    ? _buildPdfViewer(lesson)
                    : lesson.type == 'article'
                        ? _buildArticleViewer(lesson)
                        : _buildPlaceholder(lesson),
          ),

          // Bottom controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (lesson.videoDuration != null)
                        Text('المدة: ${Duration(seconds: lesson.videoDuration!).toString().substring(2, 7)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.settings_outlined),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 48, color: AppTheme.primaryColor),
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.speed_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(LessonModel lesson) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, size: 80, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            const Text('مشغل الفيديو', style: TextStyle(color: Colors.white70, fontSize: 18)),
            if (lesson.videoUrl != null) ...[
              const SizedBox(height: 8),
              Text(lesson.videoUrl!, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer(LessonModel lesson) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text('عارض PDF', style: TextStyle(fontSize: 18)),
          if (lesson.pdfName != null)
            Text(lesson.pdfName!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: const Text('تحميل PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleViewer(LessonModel lesson) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(lesson.articleContent ?? 'المحتوى غير متوفر',
            style: const TextStyle(fontSize: 16, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(LessonModel lesson) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv, size: 80, color: Colors.purple.shade200),
          const SizedBox(height: 16),
          Text('${lesson.type} - ${lesson.title}', style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
