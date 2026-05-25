import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _notifs = [];
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await _api.get('/notifications');
      if (res.data['success'] == true && mounted) {
        setState(() {
          _notifs = res.data['data']['notifications'] ?? [];
          _unread = res.data['data']['unread_count'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.put('/notifications/read-all');
      setState(() => _unread = 0);
    } catch (_) {}
  }

  Future<void> _markRead(String id) async {
    try {
      await _api.put('/notifications/$id/read');
      _loadNotifications();
    } catch (_) {}
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'course_update': return Icons.update;
      case 'new_course': return Icons.video_library;
      case 'subscription': return Icons.subscriptions;
      case 'payment': return Icons.payment;
      case 'approval': return Icons.check_circle;
      case 'announcement': return Icons.campaign;
      case 'promotion': return Icons.discount;
      case 'reminder': return Icons.alarm;
      default: return Icons.notifications;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'payment': return Colors.green;
      case 'approval': return Colors.blue;
      case 'promotion': return Colors.orange;
      case 'reminder': return Colors.purple;
      case 'announcement': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('تحديد الكل كمقروء'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('لا توجد إشعارات', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifs.length,
                    itemBuilder: (_, i) {
                      final n = _notifs[i];
                      final isRead = n['is_read'] == 1;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isRead ? null : AppTheme.primaryColor.withValues(alpha: 0.03),
                        child: ListTile(
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _getColor(n['type'] ?? '').withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getIcon(n['type'] ?? ''), color: _getColor(n['type'] ?? '')),
                          ),
                          title: Text(n['title'] ?? '', style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          )),
                          subtitle: Text(n['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_timeAgo(n['created_at'] ?? ''),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              if (!isRead)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor, shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            if (!isRead) _markRead(n['id']);
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _timeAgo(String dateStr) {
    try {
      final date = DateTime.parse('${dateStr}Z');
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
      if (diff.inDays < 1) return 'منذ ${diff.inHours} س';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} ي';
      return dateStr.substring(0, 10);
    } catch (_) {
      return dateStr.substring(0, 10);
    }
  }
}
