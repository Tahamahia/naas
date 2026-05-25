import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/subscription_model.dart';
import '../../course_detail/pages/course_detail_page.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;
  List<SubscriptionModel> _active = [];
  List<SubscriptionModel> _expired = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/subscriptions/my');
      if (res.data['success'] == true && mounted) {
        final all = (res.data['data'] as List).map((s) => SubscriptionModel.fromJson(s)).toList();
        setState(() {
          _active = all.where((s) => s.isActive && !s.hasEnded).toList();
          _expired = all.where((s) => s.isExpired || s.hasEnded).toList();
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
      appBar: AppBar(
        title: const Text('كورساتي'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'النشطة (${_active.length})'),
            Tab(text: 'المنتهية (${_expired.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_active, isActive: true),
                _buildList(_expired, isActive: false),
              ],
            ),
    );
  }

  Widget _buildList(List<SubscriptionModel> subs, {required bool isActive}) {
    if (subs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.book_outlined : Icons.book_online_outlined,
              size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isActive ? 'لا توجد اشتراكات نشطة' : 'لا توجد اشتراكات منتهية',
              style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subs.length,
        itemBuilder: (_, i) {
          final sub = subs[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CourseDetailPage(courseId: sub.courseId),
                ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  if (isActive)
                    LinearProgressIndicator(
                      value: sub.progressPercent / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: AppTheme.primaryColor,
                      minHeight: 3,
                    ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: sub.courseThumbnail != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(8),
                                  child: Image.network(sub.courseThumbnail!, fit: BoxFit.cover))
                              : const Icon(Icons.school, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub.courseTitle ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (sub.teacherName != null)
                                Text(sub.teacherName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 4),
                              if (isActive) ...[
                                Text('${sub.progressPercent.toStringAsFixed(0)}% مكتمل',
                                  style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                              ] else ...[
                                Text('انتهى: ${sub.endDate?.substring(0, 10) ?? '-'}',
                                  style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            if (isActive)
                              const Icon(Icons.play_circle_fill, color: AppTheme.primaryColor, size: 28),
                            if (!isActive)
                              TextButton(
                                onPressed: () {},
                                child: const Text('تجديد', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
