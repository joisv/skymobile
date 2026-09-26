enum NotificationType {
  overdue,
  pickupToday,
  maintenance,
  closing,
  info,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? bookingCode;
  final String? assetCode;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.bookingCode,
    this.assetCode,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? bookingCode,
    String? assetCode,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      bookingCode: bookingCode ?? this.bookingCode,
      assetCode: assetCode ?? this.assetCode,
    );
  }
}
