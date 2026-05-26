import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_client.dart';
import '../../../models/user_model.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _api = ApiClient();

  AuthBloc() : super(AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<RegisterEvent>(_onRegister);
    on<CheckAuthEvent>(_onCheckAuth);
    on<LogoutEvent>(_onLogout);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<RefreshUserEvent>(_onRefreshUser);
  }

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final res = await _api.post('/auth/login', data: {
        'email': event.email,
        'password': event.password,
      });
      if (res.data['success'] == true) {
        final data = res.data['data'];
        await _api.setTokens(data['accessToken'], data['refreshToken']);
        emit(AuthAuthenticated(UserModel.fromJson(data['user'])));
      } else {
        emit(AuthError(res.data['message'] ?? 'Login failed'));
      }
    } catch (e) {
      emit(AuthError('Login failed: ${e.toString()}'));
    }
  }

  Future<void> _onRegister(RegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final res = await _api.post('/auth/register', data: {
        'email': event.email,
        'password': event.password,
        'full_name': event.fullName,
        'phone': event.phone,
      });
      if (res.data['success'] == true) {
        final data = res.data['data'];
        await _api.setTokens(data['accessToken'], data['refreshToken']);
        emit(AuthAuthenticated(UserModel.fromJson(data['user'])));
      } else {
        emit(AuthError(res.data['message'] ?? 'Registration failed'));
      }
    } catch (e) {
      emit(AuthError('Registration failed: ${e.toString()}'));
    }
  }

  Future<void> _onCheckAuth(CheckAuthEvent event, Emitter<AuthState> emit) async {
    final token = await _api.getToken();
    if (token == null) {
      emit(AuthUnauthenticated());
      return;
    }
    try {
      final res = await _api.get('/auth/me');
      if (res.data['success'] == true) {
        emit(AuthAuthenticated(UserModel.fromJson(res.data['data'])));
      } else {
        await _api.clearTokens();
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await _api.clearTokens();
    emit(AuthUnauthenticated());
  }

  Future<void> _onUpdateProfile(UpdateProfileEvent event, Emitter<AuthState> emit) async {
    if (state is AuthAuthenticated) {
      try {
        await _api.put('/auth/profile', data: event.data);
        final res = await _api.get('/auth/me');
        if (res.data['success'] == true) {
          emit(AuthAuthenticated(UserModel.fromJson(res.data['data'])));
        }
      } catch (_) {}
    }
  }
  Future<void> _onRefreshUser(RefreshUserEvent event, Emitter<AuthState> emit) async {
    if (state is AuthAuthenticated) {
      try {
        final res = await _api.get('/auth/me');
        if (res.data['success'] == true) {
          emit(AuthAuthenticated(UserModel.fromJson(res.data['data'])));
        }
      } catch (_) {}
    }
  }
}
