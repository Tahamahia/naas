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
  String? _selectedRole;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.roleFilter;
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'limit': '100'};
      if (_selectedRole != null && _selectedRole!.isNotEmpty) params['role'] = _selectedRole;
      final res = await _api.get('/admin/users', queryParams: params);
      if (res.data['success'] == true && mounted) {
        setState(() { _users = res.data['data'] as List; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleBan(String userId, bool shouldBan) async {
    final action = shouldBan ? 'حظر' : 'إلغاء حظر';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action المستخدم'),
        content: Text('هل تريد $action هذا المستخدم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: shouldBan ? Colors.red : Colors.green),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/admin/users/$userId/${shouldBan ? 'ban' : 'unban'}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $action المستخدم بنجاح'), backgroundColor: Colors.green),
        );
      }
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل $action المستخدم'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<dynamic> get _filteredUsers {
    final query = _searchCtrl.text.toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين')),
      body: Column(
        children: [
          // Search + Filter bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو الإيميل...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedRole,
                  hint: const Text('الكل'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('الكل')),
                    DropdownMenuItem(value: 'student', child: Text('طالب')),
                    DropdownMenuItem(value: 'teacher', child: Text('أستاذ')),
                    DropdownMenuItem(value: 'admin', child: Text('مشرف')),
                    DropdownMenuItem(value: 'super_admin', child: Text('مشرف عام')),
                  ],
                  onChanged: (v) {
                    _selectedRole = v;
                    _loadUsers();
                  },
                ),
              ],
            ),
          ),
          // Users list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('لا يوجد مستخدمين'))
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final u = users[i];
                            final isBanned = u['status'] == 'banned';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _roleColor(u['role']),
                                  child: Text((u['full_name'] as String? ?? '?')[0],
                                      style: const TextStyle(color: Colors.white)),
                                ),
                                title: Text(u['full_name'] ?? ''),
                                subtitle: Text('${u['email']}\n${_roleLabel(u['role'])}',
                                    style: const TextStyle(fontSize: 12)),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBanned)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                        child: const Text('محظور', style: TextStyle(fontSize: 10, color: Colors.red)),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                        child: const Text('نشط', style: TextStyle(fontSize: 10, color: Colors.green)),
                                      ),
                                    PopupMenuButton(
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: isBanned ? 'unban' : 'ban',
                                          child: Text(isBanned ? 'إلغاء الحظر' : 'حظر',
                                              style: TextStyle(color: isBanned ? Colors.green : Colors.red)),
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
          ),
        ],
      ),
    );
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'super_admin': return Colors.purple;
      case 'admin': return Colors.indigo;
      case 'teacher': return Colors.orange;
      default: return Colors.blue;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'super_admin': return 'مشرف عام';
      case 'admin': return 'مشرف';
      case 'teacher': return 'أستاذ';
      default: return 'طالب';
    }
  }
}
