import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/categories');
      if (res.data['success'] == true && mounted) {
        setState(() { _categories = res.data['data'] as List; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? category}) async {
    final ctrl = TextEditingController(text: category?['name'] ?? '');
    final isEdit = category != null;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'تعديل القسم' : 'إضافة قسم جديد'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'اسم القسم'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(isEdit ? 'حفظ' : 'إضافة')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    try {
      if (isEdit) {
        await _api.put('/categories/${category['id']}', data: {'name': result.trim()});
      } else {
        await _api.post('/categories', data: {'name': result.trim(), 'icon': 'category'});
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'تم التعديل' : 'تم الإضافة'), backgroundColor: Colors.green));
      _loadCategories();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت العملية'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القسم'),
        content: Text('هل تريد حذف "$name"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete('/categories/$id');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
      _loadCategories();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحذف'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الأقسام')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddEditDialog(), icon: const Icon(Icons.add), label: const Text('قسم جديد')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('لا توجد أقسام', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.category, color: Colors.blue)),
                          title: Text(cat['name'] ?? ''),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditDialog(category: cat)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCategory(cat['id'], cat['name'] ?? '')),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
