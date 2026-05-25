import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/course_model.dart';
import '../../../models/user_model.dart';
import '../../auth/bloc/auth_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiClient _api = ApiClient();
  List<CourseModel> _courses = [];
  List<dynamic> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final coursesRes = await _api.get('/courses', queryParams: {'limit': '10', 'sort': 'students'});
      final catsRes = await _api.get('/categories');
      if (mounted) {
        setState(() {
          if (coursesRes.data['success'] == true) {
            _courses = (coursesRes.data['data'] as List).map((c) => CourseModel.fromJson(c)).toList();
          }
          if (catsRes.data['success'] == true) {
            _categories = catsRes.data['data'] as List;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state is AuthAuthenticated ? (b.state as AuthAuthenticated).user : null);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ناس', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(child: const Icon(Icons.notifications_outlined)),
            onPressed: () {},
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null ? Text(user.fullName[0]) : null,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Welcome card
                  if (user != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('مرحبا بك، ${user.fullName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('الرصيد: ${user.walletBalance.toStringAsFixed(2)} د.ل',
                                    style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor, size: 40),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Categories
                  if (_categories.isNotEmpty) ...[
                    const Text('الأقسام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          return ActionChip(
                            label: Text(cat['name'] ?? ''),
                            avatar: cat['icon'] != null ? Icon(Icons.category, size: 18) : null,
                            onPressed: () {},
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Most popular courses
                  const Text('الأكثر شهرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _courses.isEmpty
                      ? const Center(child: Text('لا توجد كورسات بعد'))
                      : SizedBox(
                          height: 240,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _courses.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, i) => _CourseCard(course: _courses[i]),
                          ),
                        ),

                  // Quick actions for teacher/admin
                  if (user != null && user.isTeacher) ..._teacherActions(user),
                  if (user != null && user.isAdmin) ..._adminActions(user),
                ],
              ),
      ),
    );
  }

  List<Widget> _teacherActions(UserModel user) {
    return [
      const SizedBox(height: 24),
      const Text('لوحة الأستاذ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(
        children: [
          _ActionCard(icon: Icons.video_library, label: 'كورساتي', color: Colors.blue, onTap: () {}),
          const SizedBox(width: 12),
          _ActionCard(icon: Icons.monetization_on, label: 'الأرباح', color: Colors.green, onTap: () {}),
          const SizedBox(width: 12),
          _ActionCard(icon: Icons.people, label: 'الطلاب', color: Colors.orange, onTap: () {}),
        ],
      ),
    ];
  }

  List<Widget> _adminActions(UserModel user) {
    return [
      const SizedBox(height: 24),
      const Text('لوحة الإدارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(
        children: [
          _ActionCard(icon: Icons.dashboard, label: 'لوحة التحكم', color: Colors.purple, onTap: () {}),
          const SizedBox(width: 12),
          _ActionCard(icon: Icons.people, label: 'المستخدمين', color: Colors.teal, onTap: () {}),
          const SizedBox(width: 12),
          _ActionCard(icon: Icons.school, label: 'الأساتذة', color: Colors.indigo, onTap: () {}),
        ],
      ),
    ];
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: course.thumbnailUrl != null
                  ? Image.network(course.thumbnailUrl!, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.school, size: 40, color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  if (course.teacherName != null)
                    Text(course.teacherName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: AppTheme.goldColor),
                      Text(' ${course.averageRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text(course.priceFormatted, style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: course.isFree ? Colors.green : AppTheme.primaryColor,
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
