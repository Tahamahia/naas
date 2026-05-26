import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/pages/player_page.dart';
import '../bloc/course_detail_bloc.dart';

class CourseDetailPage extends StatelessWidget {
  final String courseId;
  const CourseDetailPage({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CourseDetailBloc()..add(LoadCourseDetail(courseId)),
      child: _CourseDetailView(courseId: courseId),
    );
  }
}

class _CourseDetailView extends StatefulWidget {
  final String courseId;
  const _CourseDetailView({required this.courseId});

  @override
  State<_CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<_CourseDetailView> {
  final ApiClient _api = ApiClient();
  List<dynamic> _reviews = [];
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final res = await _api.get('/reviews/${widget.courseId}');
      if (res.data['success'] == true && mounted) {
        setState(() {
          _reviews = res.data['data'] as List? ?? [];
          _reviewsLoading = false;
        });
      } else {
        if (mounted) setState(() => _reviewsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _addToCart(String courseId) async {
    try {
      final res = await _api.post('/cart/add', data: {'course_id': courseId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.data['message'] ?? (res.data['data']?['subscribed'] == true ? 'تم الاشتراك في الكورس المجاني' : 'أضيف إلى السلة')),
            backgroundColor: Colors.green,
          ),
        );
        if (res.data['data']?['subscribed'] == true) {
          context.read<CourseDetailBloc>().add(CheckSubscription(widget.courseId));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشلت العملية'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseDetailBloc, CourseDetailState>(
      builder: (context, state) {
        if (state is CourseDetailLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state is CourseDetailError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(state.message)),
          );
        }
        if (state is CourseDetailLoaded) {
          final course = state.course;
          final isSubscribed = state.isSubscribed;

          return Scaffold(
            body: CustomScrollView(
              slivers: [
                // Header
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: Colors.grey.shade900,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (course.thumbnailUrl != null)
                            Image.network(course.thumbnailUrl!, fit: BoxFit.cover)
                          else
                            const Center(child: Icon(Icons.school, size: 80, color: Colors.white24)),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(course.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                if (course.teacherName != null)
                                  Text(course.teacherName!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Body
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price & rating
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('السعر', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    Text(course.priceFormatted, style: TextStyle(
                                      fontSize: 24, fontWeight: FontWeight.bold,
                                      color: course.isFree ? Colors.green : AppTheme.primaryColor,
                                    )),
                                  ],
                                ),
                                const Spacer(),
                                Column(
                                  children: [
                                    Row(children: [
                                      Icon(Icons.star, color: AppTheme.goldColor, size: 20),
                                      Text(' ${course.averageRating.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(' (${course.totalReviews})', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text('${course.totalStudents} طالب', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                                if (course.durationDays != null) ...[
                                  const SizedBox(width: 16),
                                  Column(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 20),
                                      Text('${course.durationDays} يوم', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        if (course.description != null && course.description!.isNotEmpty) ...[
                          const Text('عن الكورس', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(course.description!, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
                          const SizedBox(height: 16),
                        ],

                        // Course content
                        Text('محتوى الكورس', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (course.sections != null && course.sections!.isNotEmpty)
                          ...course.sections!.map((section) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${section.lessons?.length ?? 0} درس'),
                              initiallyExpanded: true,
                              children: section.lessons?.map((lesson) => ListTile(
                                dense: true,
                                leading: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: _getLessonColor(lesson.type).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_getLessonIcon(lesson.type), size: 16, color: _getLessonColor(lesson.type)),
                                ),
                                title: Text(lesson.title, style: const TextStyle(fontSize: 14)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (lesson.isFree)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('مجاني', style: TextStyle(fontSize: 10, color: Colors.green)),
                                      ),
                                    if (lesson.videoDuration != null)
                                      Text(' ${Duration(seconds: lesson.videoDuration!).toString().substring(2, 7)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                                onTap: () {
                                  if (isSubscribed || lesson.isFree) {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => PlayerPage(lesson: lesson),
                                    ));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('اشترك في الكورس لمشاهدة هذا الدرس')),
                                    );
                                  }
                                },
                              )).toList() ?? [],
                            ),
                          ))
                        else
                          const Center(child: Text('لا توجد دروس بعد')),

                        const SizedBox(height: 24),

                        // قسم التقييمات
                        _buildReviewsSection(course, isSubscribed),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isSubscribed
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to first lesson if available
                          if (course.sections != null && course.sections!.isNotEmpty) {
                            final firstLesson = course.sections!.first.lessons?.first;
                            if (firstLesson != null) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PlayerPage(lesson: firstLesson),
                              ));
                            }
                          }
                        },
                        icon: const Icon(Icons.play_circle),
                        label: const Text('شاهد الدروس'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  )
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () => _addToCart(course.id),
                        icon: Icon(course.isFree ? Icons.check_circle : Icons.shopping_cart),
                        label: Text(course.isFree ? 'اشترك مجاناً' : 'أضف إلى السلة - ${course.priceFormatted}'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: course.isFree ? Colors.green : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
          );
        }
        return const SizedBox();
      },
    );
  }

  IconData _getLessonIcon(String type) {
    switch (type) {
      case 'video': return Icons.play_circle_outline;
      case 'pdf': return Icons.picture_as_pdf;
      case 'quiz': return Icons.quiz_outlined;
      case 'live': return Icons.live_tv;
      case 'article': return Icons.article_outlined;
      default: return Icons.play_circle_outline;
    }
  }

  Color _getLessonColor(String type) {
    switch (type) {
      case 'video': return Colors.blue;
      case 'pdf': return Colors.red;
      case 'quiz': return Colors.orange;
      case 'live': return Colors.purple;
      case 'article': return Colors.teal;
      default: return Colors.grey;
    }
  }

  Widget _buildReviewsSection(dynamic course, bool isSubscribed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('التقييمات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (isSubscribed)
              TextButton.icon(
                onPressed: () => _showAddReviewDialog(course.id),
                icon: const Icon(Icons.rate_review, size: 18),
                label: const Text('أضف تقييم'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // ملخص التقييمات
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(course.averageRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < course.averageRating.round() ? Icons.star : Icons.star_border,
                        color: AppTheme.goldColor, size: 18,
                      )),
                    ),
                    const SizedBox(height: 4),
                    Text('${course.totalReviews} تقييم',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // قائمة التقييمات
        if (_reviewsLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ))
        else if (_reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('لا توجد تقييمات بعد', style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          ...List.generate(_reviews.length, (i) {
            final review = _reviews[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            (review['user_name'] ?? '?')[0],
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(review['user_name'] ?? 'مستخدم',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Row(
                                children: [
                                  ...List.generate(5, (s) => Icon(
                                    s < (review['rating'] ?? 0) ? Icons.star : Icons.star_border,
                                    color: AppTheme.goldColor, size: 14,
                                  )),
                                  const SizedBox(width: 8),
                                  Text(_formatReviewDate(review['created_at'] ?? ''),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(review['comment'], style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatReviewDate(String dateStr) {
    try {
      final date = DateTime.parse('${dateStr}Z');
      final diff = DateTime.now().difference(date);
      if (diff.inDays < 1) return 'اليوم';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
      if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
      return dateStr.substring(0, 10);
    } catch (_) {
      return '';
    }
  }

  Future<void> _showAddReviewDialog(String courseId) async {
    int selectedRating = 5;
    final commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('أضف تقييمك'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(
                    i < selectedRating ? Icons.star : Icons.star_border,
                    color: AppTheme.goldColor, size: 32,
                  ),
                  onPressed: () => setDialogState(() => selectedRating = i + 1),
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اكتب تعليقك هنا (اختياري)...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      final res = await _api.post('/reviews/$courseId', data: {
        'rating': selectedRating,
        'comment': commentController.text.trim(),
      });
      if (mounted) {
        if (res.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال تقييمك بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          _loadReviews();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data['message'] ?? 'فشل إرسال التقييم'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إرسال التقييم'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    commentController.dispose();
  }
}
