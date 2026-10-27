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
    final affId = json['affiliate_id'] ?? json['branch_id'];
    final affName = json['affiliate_name'] ?? json['branch_name'] ?? (json['branch'] is Map ? (json['branch'] as Map)['name'] : null);
    final uName = json['user_name'] ?? json['requested_by_name'] ?? (json['requested_by'] is Map ? (json['requested_by'] as Map)['name'] : null);
    final notes = json['notes'] ?? json['title'];
    final spent = json['spent_at'] ?? json['disbursed_at'] ?? json['created_at'];

    return ExpenseModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      affiliateId: affId is int
          ? affId
          : int.tryParse(affId?.toString() ?? '0') ?? 0,
      affiliateName: affName?.toString() ?? 'Pusat',
      userId: json['user_id']?.toString() ?? json['requested_by']?.toString(),
      userName: uName?.toString() ?? 'Staff',
      amount: amt,
      amountFormatted: json['amount_formatted'] as String? ?? '',
      category: json['category'] as String? ?? 'operasional',
      categoryLabel: json['category_label'] as String? ?? '',
      notes: notes?.toString(),
      spentAt: spent != null ? DateTime.tryParse(spent.toString()) : null,
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

  factory ExpenseSummaryModel.fromJson(dynamic json) {
    if (json is! Map) {
      return const ExpenseSummaryModel(
        totalExpenses: 0.0,
        totalExpensesFormatted: 'Rp 0',
        count: 0,
        categories: {},
      );
    }
    final map = json;
    final catRaw = (map['categories'] is Map ? map['categories'] as Map : null) ??
        (map['by_category'] is Map ? map['by_category'] as Map : null) ??
        {};
    final catMap = <String, double>{};
    catRaw.forEach((k, v) {
      if (v is num) {
        catMap[k.toString()] = v.toDouble();
      } else if (v is Map && v['total'] is num) {
        catMap[k.toString()] = (v['total'] as num).toDouble();
      }
    });

    final totalExp = (map['total_expenses'] as num?)?.toDouble() ??
        (map['totalExpenses'] as num?)?.toDouble() ??
        0.0;
    final count = map['count'] is int ? map['count'] as int : int.tryParse(map['count']?.toString() ?? '0') ?? 0;

    return ExpenseSummaryModel(
      totalExpenses: totalExp,
      totalExpensesFormatted: map['total_expenses_formatted'] as String? ?? 'Rp ${totalExp.toInt()}',
      count: count,
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
    List<ExpenseModel> list = [];
    dynamic summaryData;

    final dataField = json['data'];
    if (dataField is List) {
      list = dataField
          .whereType<Map>()
          .map((e) => ExpenseModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (dataField is Map) {
      final expensesList = dataField['expenses'] ?? dataField['data'] ?? dataField['items'];
      if (expensesList is List) {
        list = expensesList
            .whereType<Map>()
            .map((e) => ExpenseModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      summaryData = dataField['summary'];
    }

    summaryData ??= json['summary'];

    return ExpenseResponseModel(
      status: json['status']?.toString() ?? (json['success'] == true ? 'success' : 'success'),
      period: json['period']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      summary: ExpenseSummaryModel.fromJson(summaryData),
      data: list,
    );
  }
}
