import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final res = await _api.get('/live/upcoming');
      if (res.data['success'] == true && mounted) {
        setState(() { _sessions = res.data['data'] as List; _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الجلسات المباشرة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.live_tv, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا توجد جلسات قادمة', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.live_tv, color: Colors.purple.shade400),
                        ),
                        title: Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (s['course_title'] != null) Text(s['course_title']),
                            Text('${s['scheduled_at']?.substring(0, 16) ?? ""} • ${s['duration_minutes'] ?? "?"} دقيقة',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        trailing: s['status'] == 'live'
                            ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text('مباشر', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ]))
                            : const Icon(Icons.chevron_left),
                        onTap: () {},
                      ),
                    );
                  },
                ),
    );
  }
}
