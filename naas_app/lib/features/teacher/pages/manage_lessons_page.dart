import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../widgets/lesson_upload_dialog.dart';

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
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LessonUploadDialog(
        courseId: widget.courseId,
        sectionId: sectionId,
      ),
    );
    if (result == true) {
      _loadCourse();
    }
  }

  Future<void> _renameSection(String sectionId, String currentTitle) async {
    final titleCtrl = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تسمية القسم'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'اسم القسم'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, titleCtrl.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != currentTitle) {
      try {
        await _api.put('/courses/sections/$sectionId', data: {'title': result});
        _loadCourse();
      } catch (_) {}
    }
  }

  Future<void> _deleteSection(String sectionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف القسم'),
        content: const Text('هل أنت متأكد من حذف هذا القسم وجميع دروسه؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.delete('/courses/sections/$sectionId');
        _loadCourse();
      } catch (_) {}
    }
  }

  Future<void> _onReorderSections(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, item);
    });

    final List<Map<String, dynamic>> payload = [];
    for (int i = 0; i < _sections.length; i++) {
      _sections[i]['sort_order'] = i;
      payload.add({'id': _sections[i]['id'], 'sort_order': i});
    }

    try {
      await _api.put('/courses/${widget.courseId}/sections/reorder', data: {'sections': payload});
    } catch (_) {}
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
                  onReorder: _onReorderSections,
                  itemBuilder: (_, i) {
                    final section = _sections[i];
                    final lessons = section['lessons'] as List? ?? [];
                    return Card(
                      key: ValueKey(section['id']),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(section['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _renameSection(section['id'], section['title'] ?? ''),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _deleteSection(section['id']),
                            ),
                          ],
                        ),
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
                                } else if (v == 'edit') {
                                  // Todo: Show edit dialog
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
