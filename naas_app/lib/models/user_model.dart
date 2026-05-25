class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final String status;
  final double walletBalance;
  final int points;
  final String? referralCode;
  final String lang;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.status,
    required this.walletBalance,
    required this.points,
    this.referralCode,
    required this.lang,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] ?? '',
    email: json['email'] ?? '',
    fullName: json['full_name'] ?? '',
    phone: json['phone'],
    avatarUrl: json['avatar_url'],
    role: json['role'] ?? 'student',
    status: json['status'] ?? 'active',
    walletBalance: (json['wallet_balance'] ?? 0).toDouble(),
    points: json['points'] ?? 0,
    referralCode: json['referral_code'],
    lang: json['lang'] ?? 'ar',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
    'role': role,
    'status': status,
    'wallet_balance': walletBalance,
    'points': points,
    'referral_code': referralCode,
    'lang': lang,
  };

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isTeacher => role == 'teacher';
  bool get isSuperAdmin => role == 'super_admin';
}
