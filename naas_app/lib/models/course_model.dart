class CourseModel {
  final String id;
  final String? teacherId;
  final String? categoryId;
  final String title;
  final String? subtitle;
  final String? description;
  final double price;
  final int? durationDays;
  final String? thumbnailUrl;
  final String? introVideoUrl;
  final String? language;
  final String? level;
  final String status;
  final int totalLessons;
  final int totalDuration;
  final int totalStudents;
  final double averageRating;
  final int totalReviews;
  final String? teacherName;
  final String? teacherPhoto;
  final String? categoryName;
  final List<SectionModel>? sections;

  CourseModel({
    required this.id,
    this.teacherId,
    this.categoryId,
    required this.title,
    this.subtitle,
    this.description,
    required this.price,
    this.durationDays,
    this.thumbnailUrl,
    this.introVideoUrl,
    this.language,
    this.level,
    this.status = 'published',
    this.totalLessons = 0,
    this.totalDuration = 0,
    this.totalStudents = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.teacherName,
    this.teacherPhoto,
    this.categoryName,
    this.sections,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
    id: json['id'] ?? '',
    teacherId: json['teacher_id'],
    categoryId: json['category_id'],
    title: json['title'] ?? '',
    subtitle: json['subtitle'],
    description: json['description'],
    price: (json['price'] ?? 0).toDouble(),
    durationDays: json['duration_days'],
    thumbnailUrl: json['thumbnail_url'],
    introVideoUrl: json['intro_video_url'],
    language: json['language'],
    level: json['level'],
    status: json['status'] ?? 'published',
    totalLessons: json['total_lessons'] ?? 0,
    totalDuration: json['total_duration'] ?? 0,
    totalStudents: json['total_students'] ?? 0,
    averageRating: (json['average_rating'] ?? 0).toDouble(),
    totalReviews: json['total_reviews'] ?? 0,
    teacherName: json['teacher_name'],
    teacherPhoto: json['teacher_photo'],
    categoryName: json['category_name'],
    sections: json['sections'] != null
        ? (json['sections'] as List).map((s) => SectionModel.fromJson(s)).toList()
        : null,
  );

  bool get isFree => price == 0;
  bool get isPublished => status == 'published';

  String get priceFormatted => isFree ? 'مجاني' : '${price.toStringAsFixed(2)} د.ل';
}

class SectionModel {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int sortOrder;
  final List<LessonModel>? lessons;

  SectionModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.lessons,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) => SectionModel(
    id: json['id'] ?? '',
    courseId: json['course_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    sortOrder: json['sort_order'] ?? 0,
    lessons: json['lessons'] != null
        ? (json['lessons'] as List).map((l) => LessonModel.fromJson(l)).toList()
        : null,
  );
}

class LessonModel {
  final String id;
  final String sectionId;
  final String title;
  final String? description;
  final String type;
  final String? videoUrl;
  final int? videoDuration;
  final String? videoStatus;
  final String? pdfUrl;
  final String? pdfName;
  final String? articleContent;
  final bool isFree;
  final int sortOrder;

  LessonModel({
    required this.id,
    required this.sectionId,
    required this.title,
    this.description,
    this.type = 'video',
    this.videoUrl,
    this.videoDuration,
    this.videoStatus,
    this.pdfUrl,
    this.pdfName,
    this.articleContent,
    this.isFree = false,
    this.sortOrder = 0,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) => LessonModel(
    id: json['id'] ?? '',
    sectionId: json['section_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    type: json['type'] ?? 'video',
    videoUrl: json['video_url'],
    videoDuration: json['video_duration'],
    videoStatus: json['video_status'],
    pdfUrl: json['pdf_url'],
    pdfName: json['pdf_name'],
    articleContent: json['article_content'],
    isFree: json['is_free'] == 1 || json['is_free'] == true,
    sortOrder: json['sort_order'] ?? 0,
  );
}
