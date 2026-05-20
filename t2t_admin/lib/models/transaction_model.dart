import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class TransactionModel {
  final String id;
  final String userId;
  final String studentName;
  final String? rewardId;
  final String? rewardName;
  final int points;
  final String type; // 'deposit' or 'redeem'
  final String department;
  final String status; // 'Pending' or 'Completed'
  final String? ticketCode; // Generated for redemption transactions
  final Timestamp timestamp;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.studentName,
    this.rewardId,
    this.rewardName,
    required this.points,
    required this.type,
    required this.department,
    this.status = 'Pending',
    this.ticketCode,
    Timestamp? timestamp,
  }) : timestamp = timestamp ?? Timestamp.now();

  // Generate a random ticket code for redemption transactions
  static String generateTicketCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final code = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    return 'T2T-$code';
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionModel(
      id: docId,
      userId: map['userId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      rewardId: map['rewardId'] as String?,
      rewardName: map['rewardName'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? 'deposit',
      department: map['department'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      ticketCode: map['ticketCode'] as String?,
      timestamp: map['timestamp'] is Timestamp ? map['timestamp'] as Timestamp : Timestamp.fromDate(DateTime.parse(map['timestamp'] as String)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'studentName': studentName,
      'rewardId': rewardId,
      'rewardName': rewardName,
      'points': points,
      'type': type,
      'department': department,
      'status': status,
      'ticketCode': ticketCode,
      'timestamp': timestamp,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? studentName,
    String? rewardId,
    String? rewardName,
    int? points,
    String? type,
    String? department,
    String? status,
    String? ticketCode,
    Timestamp? timestamp,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      studentName: studentName ?? this.studentName,
      rewardId: rewardId ?? this.rewardId,
      rewardName: rewardName ?? this.rewardName,
      points: points ?? this.points,
      type: type ?? this.type,
      department: department ?? this.department,
      status: status ?? this.status,
      ticketCode: ticketCode ?? this.ticketCode,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
