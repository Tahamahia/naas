import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class CreateCoursePage extends StatefulWidget {
  final String? editCourseId;
  const CreateCoursePage({super.key, this.editCourseId});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  double _price = 0;
  int? _durationDays;
  String? _selectedCategory;
  String _level = 'all';
  String _dripType = 'none';
  List<dynamic> _categories = [];
  bool _saving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.editCourseId != null;
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.get('/categories');
      if (res.data['success'] == true && mounted) {
        setState(() => _categories = res.data['data'] as List);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final data = {
        'title': _titleCtrl.text,
        'subtitle': _subtitleCtrl.text,
        'description': _descCtrl.text,
        'price': _price,
        'duration_days': _durationDays,
        'category_id': _selectedCategory,
        'level': _level,
        'drip_type': _dripType,
      };

      final res = _isEditing
          ? await _api.put('/courses/${widget.editCourseId}', data: data)
          : await _api.post('/courses', data: data);

      if (mounted) {
        if (res.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditing ? 'تم تحديث الكورس' : 'تم إنشاء الكورس'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'فشل'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل الكورس' : 'إنشاء كورس جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'عنوان الكورس'),
                validator: (v) => v == null || v.length < 3 ? 'أدخل عنواناً للكورس' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(labelText: 'العنوان الفرعي (اختياري)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'وصف الكورس', alignLabelWithHint: true),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'السعر (د.ل)', prefixText: 'د.ل '),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _price = double.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'مدة الاشتراك (أيام)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _durationDays = int.tryParse(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'القسم'),
                items: _categories.map((cat) => DropdownMenuItem<String>(
                  value: cat['id'] as String?,
                  child: Text(cat['name'] as String? ?? ''),
                )).toList(),
                onChanged: (v) => _selectedCategory = v,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'المستوى'),
                value: _level,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'beginner', child: Text('مبتدئ')),
                  DropdownMenuItem(value: 'intermediate', child: Text('متوسط')),
                  DropdownMenuItem(value: 'advanced', child: Text('متقدم')),
                ],
                onChanged: (v) => _level = v ?? 'all',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نظام فتح الدروس'),
                value: _dripType,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('كل الدروس مفتوحة')),
                  DropdownMenuItem(value: 'days', child: Text('فتح حسب أيام محددة')),
                ],
                onChanged: (v) => _dripType = v ?? 'none',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditing ? 'حفظ التعديلات' : 'إنشاء الكورس'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
