class SubscriptionModel {
  final String id;
  final String courseId;
  final double amount;
  final String startDate;
  final String? endDate;
  final String status;
  final bool isFree;
  final String? courseTitle;
  final String? courseThumbnail;
  final int? totalLessons;
  final String? teacherName;
  final double progressPercent;

  SubscriptionModel({
    required this.id,
    required this.courseId,
    required this.amount,
    required this.startDate,
    this.endDate,
    required this.status,
    this.isFree = false,
    this.courseTitle,
    this.courseThumbnail,
    this.totalLessons,
    this.teacherName,
    this.progressPercent = 0,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => SubscriptionModel(
    id: json['id'] ?? '',
    courseId: json['course_id'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    startDate: json['start_date'] ?? '',
    endDate: json['end_date'],
    status: json['status'] ?? 'active',
    isFree: json['is_free'] == 1 || json['is_free'] == true,
    courseTitle: json['title'],
    courseThumbnail: json['thumbnail_url'],
    totalLessons: json['total_lessons'],
    teacherName: json['teacher_name'],
    progressPercent: (json['progress_percent'] ?? 0).toDouble(),
  );

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';
  bool get hasEnded {
    if (endDate == null) return false;
    return DateTime.parse('${endDate}Z').isBefore(DateTime.now());
  }
}
