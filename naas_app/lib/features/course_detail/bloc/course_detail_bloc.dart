import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_client.dart';
import '../../../models/course_model.dart';

part 'course_detail_event.dart';
part 'course_detail_state.dart';

class CourseDetailBloc extends Bloc<CourseDetailEvent, CourseDetailState> {
  final ApiClient _api = ApiClient();

  CourseDetailBloc() : super(CourseDetailInitial()) {
    on<LoadCourseDetail>(_onLoad);
    on<CheckSubscription>(_onCheckSubscription);
  }

  Future<void> _onLoad(LoadCourseDetail event, Emitter<CourseDetailState> emit) async {
    emit(CourseDetailLoading());
    try {
      final res = await _api.get('/courses/${event.courseId}');
      if (res.data['success'] == true) {
        final course = CourseModel.fromJson(res.data['data']);
        emit(CourseDetailLoaded(course));
      } else {
        emit(CourseDetailError(res.data['message'] ?? 'Failed to load'));
      }
    } catch (e) {
      emit(CourseDetailError('Failed to load course: ${e.toString()}'));
    }
  }

  Future<void> _onCheckSubscription(CheckSubscription event, Emitter<CourseDetailState> emit) async {
    if (state is CourseDetailLoaded) {
      try {
        final res = await _api.get('/subscriptions/my', queryParams: {'status': 'active'});
        if (res.data['success'] == true) {
          final subs = res.data['data'] as List;
          final subscribed = subs.any((s) => s['course_id'] == event.courseId);
          final current = state as CourseDetailLoaded;
          emit(CourseDetailLoaded(current.course, isSubscribed: subscribed));
        }
      } catch (_) {}
    }
  }
}
