part of 'course_detail_bloc.dart';

abstract class CourseDetailState extends Equatable {
  const CourseDetailState();
  @override
  List<Object?> get props => [];
}

class CourseDetailInitial extends CourseDetailState {}

class CourseDetailLoading extends CourseDetailState {}

class CourseDetailLoaded extends CourseDetailState {
  final CourseModel course;
  final bool isSubscribed;
  const CourseDetailLoaded(this.course, {this.isSubscribed = false});
  @override
  List<Object?> get props => [course, isSubscribed];
}

class CourseDetailError extends CourseDetailState {
  final String message;
  const CourseDetailError(this.message);
  @override
  List<Object?> get props => [message];
}
