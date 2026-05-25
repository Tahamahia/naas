import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await _api.get('/admin/dashboard');
      if (res.data['success'] == true && mounted) {
        setState(() {
          _stats = res.data['data'];
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
        title: const Text('لوحة الإدارة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats grid
                if (_stats != null) ...[
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _StatCard(title: 'المستخدمين', value: '${_stats!['users'] ?? 0}', icon: Icons.people, color: Colors.blue),
                      _StatCard(title: 'الكورسات', value: '${_stats!['courses']?['published'] ?? 0}', icon: Icons.video_library, color: Colors.green),
                      _StatCard(title: 'الأساتذة', value: '${_stats!['teachers']?['approved'] ?? 0}', icon: Icons.school, color: Colors.orange),
                      _StatCard(title: 'الاشتراكات', value: '${_stats!['subscriptions']?['active'] ?? 0}', icon: Icons.subscriptions, color: Colors.purple),
                      _StatCard(title: 'الإيرادات', value: '${(_stats!['revenue'] ?? 0).toStringAsFixed(0)} د.ل', icon: Icons.monetization_on, color: Colors.teal),
                      _StatCard(title: 'الإيداعات', value: '${(_stats!['deposits'] ?? 0).toStringAsFixed(0)} د.ل', icon: Icons.account_balance, color: Colors.indigo),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pending items
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_add, color: Colors.orange),
                          title: const Text('طلبات أساتذة معلقة'),
                          trailing: Chip(label: Text('${_stats!['teachers']?['pending'] ?? 0}')),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.money_off, color: Colors.red),
                          title: const Text('طلبات سحب معلقة'),
                          trailing: Chip(label: Text('${_stats!['pending_withdrawals'] ?? 0}')),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.replay, color: Colors.blue),
                          title: const Text('طلبات استرجاع'),
                          trailing: Chip(label: Text('${_stats!['pending_refunds'] ?? 0}')),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.flag, color: Colors.purple),
                          title: const Text('بلاغات'),
                          trailing: Chip(label: Text('${_stats!['pending_reports'] ?? 0}')),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
