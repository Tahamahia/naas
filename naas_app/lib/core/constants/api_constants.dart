class ApiConstants {
  // Change this to your Cloudflare Workers URL
  static const String baseUrl = 'http://localhost:8787/api';

  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String refresh = '$baseUrl/auth/refresh';
  static const String me = '$baseUrl/auth/me';
  static const String updateProfile = '$baseUrl/auth/profile';
  static const String updateFcmToken = '$baseUrl/auth/fcm-token';

  static const String categories = '$baseUrl/categories';
  static const String courses = '$baseUrl/courses';
  static const String courseDetail = '$baseUrl/courses'; // + /:id
  static const String myCourses = '$baseUrl/courses/teacher/mine';

  static const String teachers = '$baseUrl/teachers';
  static const String teacherApply = '$baseUrl/teachers/apply';
  static const String teacherPending = '$baseUrl/teachers/pending';
  static const String teacherProfile = '$baseUrl/teachers/my/profile';
  static const String teacherEarnings = '$baseUrl/teachers/my/earnings';

  static const String cart = '$baseUrl/cart';
  static const String cartAdd = '$baseUrl/cart/add';
  static const String cartCheckout = '$baseUrl/cart/checkout';

  static const String wallet = '$baseUrl/wallet';
  static const String depositManual = '$baseUrl/wallet/deposit/manual';
  static const String depositConfirm = '$baseUrl/wallet/deposit/confirm';
  static const String depositReject = '$baseUrl/wallet/deposit/reject';
  static const String refund = '$baseUrl/wallet/refund';
  static const String refundProcess = '$baseUrl/wallet/refund/process';

  static const String subscriptions = '$baseUrl/subscriptions';
  static const String mySubscriptions = '$baseUrl/subscriptions/my';
  static const String teacherStudents = '$baseUrl/subscriptions/teacher/students';

  static const String withdrawals = '$baseUrl/withdrawals';
  static const String myWithdrawals = '$baseUrl/withdrawals/my';
  static const String pendingWithdrawals = '$baseUrl/withdrawals/pending';

  static const String reviews = '$baseUrl/reviews';
  static const String wishlist = '$baseUrl/wishlist';
  static const String notifications = '$baseUrl/notifications';
  static const String search = '$baseUrl/search';
  static const String progress = '$baseUrl/progress';
  static const String adminDashboard = '$baseUrl/admin/dashboard';
}
