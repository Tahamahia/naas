class TransactionModel {
  final String id;
  final String type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? description;
  final String status;
  final String createdAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.balanceBefore = 0,
    this.balanceAfter = 0,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
    id: json['id'] ?? '',
    type: json['type'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    balanceBefore: (json['balance_before'] ?? 0).toDouble(),
    balanceAfter: (json['balance_after'] ?? 0).toDouble(),
    description: json['description'],
    status: json['status'] ?? 'pending',
    createdAt: json['created_at'] ?? '',
  );

  String get typeLabel {
    switch (type) {
      case 'deposit_manual': return 'إيداع يدوي';
      case 'deposit_gateway': return 'إيداع عبر بوابة';
      case 'payment': return 'شراء كورس';
      case 'refund': return 'استرجاع';
      case 'commission': return 'عمولة';
      case 'referral_bonus': return 'مكافأة إحالة';
      case 'withdrawal': return 'سحب';
      default: return type;
    }
  }
}
