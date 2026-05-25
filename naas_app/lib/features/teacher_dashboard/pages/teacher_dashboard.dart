import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../teacher/pages/create_course_page.dart';
import '../../teacher/pages/manage_lessons_page.dart';
import '../../teacher/pages/withdrawal_page.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _earnings;
  List<dynamic> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final earningsRes = await _api.get('/teachers/my/earnings');
      final coursesRes = await _api.get('/courses/teacher/mine');
      if (mounted) {
        setState(() {
          if (earningsRes.data['success'] == true) _earnings = earningsRes.data['data'];
          if (coursesRes.data['success'] == true) _courses = coursesRes.data['data'] as List;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الأستاذ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Earnings Card
                  if (_earnings != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text('الرصيد المتاح', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text('${(_earnings!['available_balance'] ?? 0).toStringAsFixed(2)} د.ل',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatItem(label: 'إجمالي الأرباح', value: '${(_earnings!['total_earned'] ?? 0).toStringAsFixed(2)} د.ل'),
                                _StatItem(label: 'مسحوب', value: '${(_earnings!['total_withdrawn'] ?? 0).toStringAsFixed(2)} د.ل'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('العمولة: ثابت ${_earnings!['commission_fixed'] ?? 0} د.ل + ${_earnings!['commission_percent'] ?? 10}%', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawalPage()));
                              },
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('طلب سحب'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Courses
                  Row(
                    children: [
                      const Text('كورساتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCoursePage()));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة كورس'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_courses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.video_library_outlined, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('ليس لديك أي كورسات بعد', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCoursePage())).then((_) => _loadData());
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('أنشئ كورس جديد'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._courses.map((c) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: c['status'] == 'published' ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            c['status'] == 'published' ? Icons.check_circle : Icons.edit,
                            color: c['status'] == 'published' ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(c['status'] == 'published' ? 'منشور' : c['status'] == 'draft' ? 'مسودة' : c['status'] ?? ''),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateCoursePage(editCourseId: c['id']))).then((_) => _loadData());
                            } else if (val == 'content') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ManageLessonsPage(courseId: c['id'])));
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'content', child: Text('إدارة المحتوى والدروس')),
                            const PopupMenuItem(value: 'edit', child: Text('تعديل الكورس')),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ManageLessonsPage(courseId: c['id'])));
                        },
                      ),
                    )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCoursePage()));
        },
        icon: const Icon(Icons.add),
        label: const Text('كورس جديد'),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
