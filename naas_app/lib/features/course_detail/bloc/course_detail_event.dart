part of 'course_detail_bloc.dart';

abstract class CourseDetailEvent extends Equatable {
  const CourseDetailEvent();
  @override
  List<Object?> get props => [];
}

class LoadCourseDetail extends CourseDetailEvent {
  final String courseId;
  const LoadCourseDetail(this.courseId);
  @override
  List<Object?> get props => [courseId];
}

class CheckSubscription extends CourseDetailEvent {
  final String courseId;
  const CheckSubscription(this.courseId);
  @override
  List<Object?> get props => [courseId];
}
