import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/course_model.dart';
import '../../course_detail/pages/course_detail_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialCategoryId;
  const SearchPage({super.key, this.initialCategoryId});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ApiClient _api = ApiClient();
  final _searchCtrl = TextEditingController();
  List<CourseModel> _results = [];
  List<dynamic> _categories = [];
  String? _selectedCategory;
  String? _selectedLevel;
  String _sortBy = 'students';
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.initialCategoryId != null) {
      _selectedCategory = widget.initialCategoryId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  Future<void> _search() async {
    if (_searchCtrl.text.isEmpty && _selectedCategory == null && _selectedLevel == null) return;
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{
        if (_searchCtrl.text.isNotEmpty) 'q': _searchCtrl.text,
        if (_selectedCategory != null) 'category': _selectedCategory,
        if (_selectedLevel != null) 'level': _selectedLevel,
        'sort': _sortBy,
        'limit': '30',
      };
      final res = await _api.get('/search', queryParams: params);
      if (res.data['success'] == true && mounted) {
        setState(() {
          _results = (res.data['data']['results'] as List).map((c) => CourseModel.fromJson(c)).toList();
          _hasSearched = true;
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
        title: const Text('بحث'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث عن كورسات...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
            ),
          ),

          // Active filters
          if (_selectedCategory != null || _selectedLevel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_selectedCategory != null)
                    Chip(
                      label: Text(_categories.firstWhere((c) => c['id'] == _selectedCategory, orElse: () => {'name': _selectedCategory})['name'] ?? ''),
                      onDeleted: () => setState(() { _selectedCategory = null; _search(); }),
                    ),
                  if (_selectedLevel != null)
                    Chip(
                      label: Text(_selectedLevel!),
                      onDeleted: () => setState(() { _selectedLevel = null; _search(); }),
                    ),
                ],
              ),
            ),

          // Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('ترتيب:', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('الأشهر'), selected: _sortBy == 'students', onSelected: (_) {
                  setState(() => _sortBy = 'students');
                  _search();
                }),
                const SizedBox(width: 4),
                ChoiceChip(label: const Text('التقييم'), selected: _sortBy == 'rating', onSelected: (_) {
                  setState(() => _sortBy = 'rating');
                  _search();
                }),
                const SizedBox(width: 4),
                ChoiceChip(label: const Text('الأقل سعرا'), selected: _sortBy == 'price_asc', onSelected: (_) {
                  setState(() => _sortBy = 'price_asc');
                  _search();
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('ابحث عن أي كورس', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            Text('مثلاً: "برمجة", "تصميم", "لغة إنجليزية"',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(child: Text('لا توجد نتائج'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final course = _results[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(8),
                                  leading: Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: course.thumbnailUrl != null
                                        ? ClipRRect(borderRadius: BorderRadius.circular(8),
                                            child: Image.network(course.thumbnailUrl!, fit: BoxFit.cover))
                                        : const Icon(Icons.school),
                                  ),
                                  title: Text(course.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Row(
                                    children: [
                                      Icon(Icons.star, size: 14, color: AppTheme.goldColor),
                                      Text(' ${course.averageRating.toStringAsFixed(1)}'),
                                      Text('  •  ${course.totalStudents} طالب'),
                                      Text('  •  ${course.teacherName ?? ""}'),
                                    ],
                                  ),
                                  trailing: Text(course.priceFormatted, style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: course.isFree ? Colors.green : AppTheme.primaryColor,
                                  )),
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => CourseDetailPage(courseId: course.id),
                                    ));
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('تصفية البحث', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('المستوى'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['all', 'beginner', 'intermediate', 'advanced']
                  .map((l) => ChoiceChip(
                    label: Text({'all': 'الكل', 'beginner': 'مبتدئ', 'intermediate': 'متوسط', 'advanced': 'متقدم'}[l]!),
                    selected: _selectedLevel == l,
                    onSelected: (v) {
                      setState(() => _selectedLevel = (l == 'all') ? null : (v ? l : null));
                      Navigator.pop(context);
                      _search();
                    },
                  )).toList(),
            ),
            const SizedBox(height: 16),
            const Text('القسم'),
            const SizedBox(height: 8),
            ...(_categories.map((cat) => ListTile(
              dense: true,
              title: Text(cat['name'] ?? ''),
              onTap: () {
                setState(() => _selectedCategory = cat['id']);
                Navigator.pop(context);
                _search();
              },
            ))),
          ],
        ),
      ),
    );
  }
}
