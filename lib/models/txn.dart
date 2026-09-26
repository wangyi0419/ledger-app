import 'package:uuid/uuid.dart';

/// 单条记账记录
class Txn {
  static final Uuid _uuid = Uuid();

  final String id;
  final String type; // 'income' | 'expense'
  final double amount;
  final String category;
  final String note;
  final int dateMillis; // 记账发生日期
  final int updatedAt; // 最后修改时间，用于多端冲突解决

  Txn({
    String? id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.dateMillis,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: j['type'] as String,
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String,
        note: (j['note'] as String?) ?? '',
        dateMillis: j['dateMillis'] as int,
        updatedAt: j['updatedAt'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'dateMillis': dateMillis,
        'updatedAt': updatedAt,
      };

  Txn copyWith({
    String? type,
    double? amount,
    String? category,
    String? note,
    int? dateMillis,
    int? updatedAt,
  }) =>
      Txn(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        note: note ?? this.note,
        dateMillis: dateMillis ?? this.dateMillis,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 预置分类
class Categories {
  static const List<String> expense = [
    '餐饮',
    '交通',
    '购物',
    '居住',
    '娱乐',
    '医疗',
    '教育',
    '其他支出',
  ];

  static const List<String> income = [
    '工资',
    '奖金',
    '理财',
    '兼职',
    '其他收入',
  ];
}
