import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class ManageLessonsPage extends StatefulWidget {
  final String courseId;
  const ManageLessonsPage({super.key, required this.courseId});

  @override
  State<ManageLessonsPage> createState() => _ManageLessonsPageState();
}

class _ManageLessonsPageState extends State<ManageLessonsPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    try {
      final res = await _api.get('/courses/${widget.courseId}');
      if (res.data['success'] == true && mounted) {
        setState(() {
          _sections = res.data['data']['sections'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSection() async {
    final titleCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة قسم جديد'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'اسم القسم'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, titleCtrl.text), child: const Text('إضافة')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await _api.post('/courses/${widget.courseId}/sections', data: {
          'title': result,
          'sort_order': _sections.length,
        });
        _loadCourse();
      } catch (_) {}
    }
  }

  Future<void> _addLesson(String sectionId) async {
    final titleCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة درس جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'عنوان الدرس'),
            ),
            const SizedBox(height: 12),
            const Text('سيتم تعيين النوع كفيديو افتراضياً'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, titleCtrl.text), child: const Text('إضافة')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await _api.post('/courses/${widget.courseId}/sections/$sectionId/lessons', data: {
          'title': result,
          'type': 'video',
          'sort_order': 0,
        });
        _loadCourse();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المحتوى'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSection,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_add, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('لا توجد أقسام بعد'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _addSection,
                        child: const Text('إضافة قسم'),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sections.length,
                  onReorder: (oldI, newI) {},
                  itemBuilder: (_, i) {
                    final section = _sections[i];
                    final lessons = section['lessons'] as List? ?? [];
                    return Card(
                      key: ValueKey(section['id']),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(section['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${lessons.length} درس'),
                        children: [
                          ...lessons.map((lesson) => ListTile(
                            key: ValueKey(lesson['id']),
                            dense: true,
                            leading: Icon(
                              lesson['type'] == 'video' ? Icons.play_circle_outline :
                              lesson['type'] == 'pdf' ? Icons.picture_as_pdf :
                              Icons.article_outlined,
                              size: 20,
                            ),
                            title: Text(lesson['title'] ?? ''),
                            trailing: PopupMenuButton(
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
                              ],
                              onSelected: (v) async {
                                if (v == 'delete') {
                                  await _api.delete('/courses/lessons/${lesson['id']}');
                                  _loadCourse();
                                }
                              },
                            ),
                          )),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextButton.icon(
                              onPressed: () => _addLesson(section['id']),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('إضافة درس'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
