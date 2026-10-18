class ExpenseModel {
  final int id;
  final int affiliateId;
  final String affiliateName;
  final String? userId;
  final String userName;
  final double amount;
  final String amountFormatted;
  final String category;
  final String categoryLabel;
  final String? notes;
  final DateTime? spentAt;
  final String spentAtFormatted;
  final DateTime? createdAt;

  const ExpenseModel({
    required this.id,
    required this.affiliateId,
    this.affiliateName = 'Pusat',
    this.userId,
    this.userName = 'Staff',
    required this.amount,
    this.amountFormatted = '',
    required this.category,
    this.categoryLabel = '',
    this.notes,
    this.spentAt,
    this.spentAtFormatted = '',
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] as num?)?.toDouble() ?? 0.0;
    return ExpenseModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      affiliateId: json['affiliate_id'] is int
          ? json['affiliate_id'] as int
          : int.tryParse(json['affiliate_id']?.toString() ?? '0') ?? 0,
      affiliateName: json['affiliate_name'] as String? ?? 'Pusat',
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String? ?? 'Staff',
      amount: amt,
      amountFormatted: json['amount_formatted'] as String? ?? '',
      category: json['category'] as String? ?? 'operasional',
      categoryLabel: json['category_label'] as String? ?? '',
      notes: json['notes'] as String?,
      spentAt: json['spent_at'] != null ? DateTime.tryParse(json['spent_at'].toString()) : null,
      spentAtFormatted: json['spent_at_formatted'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'affiliate_id': affiliateId,
      'affiliate_name': affiliateName,
      'user_id': userId,
      'user_name': userName,
      'amount': amount,
      'amount_formatted': amountFormatted,
      'category': category,
      'category_label': categoryLabel,
      'notes': notes,
      'spent_at': spentAt?.toIso8601String(),
      'spent_at_formatted': spentAtFormatted,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class ExpenseSummaryModel {
  final double totalExpenses;
  final String totalExpensesFormatted;
  final int count;
  final Map<String, double> categories;

  const ExpenseSummaryModel({
    required this.totalExpenses,
    required this.totalExpensesFormatted,
    required this.count,
    required this.categories,
  });

  factory ExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    final catRaw = json['categories'] as Map<String, dynamic>? ?? {};
    final catMap = <String, double>{};
    catRaw.forEach((k, v) {
      catMap[k] = (v as num?)?.toDouble() ?? 0.0;
    });

    return ExpenseSummaryModel(
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      totalExpensesFormatted: json['total_expenses_formatted'] as String? ?? '',
      count: json['count'] is int ? json['count'] as int : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      categories: catMap,
    );
  }
}

class ExpenseResponseModel {
  final String status;
  final String period;
  final String startDate;
  final String endDate;
  final ExpenseSummaryModel summary;
  final List<ExpenseModel> data;

  const ExpenseResponseModel({
    required this.status,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.data,
  });

  factory ExpenseResponseModel.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>?)
            ?.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ExpenseResponseModel(
      status: json['status'] as String? ?? 'success',
      period: json['period'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      summary: ExpenseSummaryModel.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      data: list,
    );
  }
}
