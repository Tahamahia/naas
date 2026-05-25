import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminUsersPage extends StatefulWidget {
  final String? roleFilter;
  const AdminUsersPage({super.key, this.roleFilter});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final params = <String, dynamic>{'limit': '50'};
      if (widget.roleFilter != null) params['role'] = widget.roleFilter;
      final res = await _api.get('/admin/users', queryParams: params);
      if (res.data['success'] == true && mounted) {
        setState(() { _users = res.data['data'] as List; _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleBan(String userId, bool banned) async {
    try {
      await _api.post('/admin/users/${banned ? 'unban' : 'ban'}');
      _loadUsers();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.roleFilter != null ? '${widget.roleFilter}s' : 'المستخدمين')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text((u['full_name'] as String? ?? '?')[0])),
                      title: Text(u['full_name'] ?? ''),
                      subtitle: Text('${u['email']} • ${u['role']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (u['status'] == 'banned')
                            Chip(label: const Text('محظور', style: TextStyle(fontSize: 10)), backgroundColor: Colors.red.shade50)
                          else
                            Chip(label: const Text('نشط', style: TextStyle(fontSize: 10)), backgroundColor: Colors.green.shade50),
                          PopupMenuButton(
                            itemBuilder: (_) => [
                              PopupMenuItem(value: u['status'] == 'banned' ? 'unban' : 'ban',
                                child: Text(u['status'] == 'banned' ? 'إلغاء الحظر' : 'حظر', style: TextStyle(color: u['status'] == 'banned' ? Colors.green : Colors.red)),
                              ),
                            ],
                            onSelected: (v) => _toggleBan(u['id'], v == 'ban'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
