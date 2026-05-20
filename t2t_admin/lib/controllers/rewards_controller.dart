import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reward_model.dart';
import '../models/student_model.dart';
import '../models/transaction_model.dart';

class RewardsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of rewards for the current user's department
  Stream<List<RewardModel>> getRewardsStream(String department) {
    return _firestore
        .collection('rewards')
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snapshot) {
          final allRewards =
              snapshot.docs.map((doc) {
                return RewardModel.fromMap(doc.data(), doc.id);
              }).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return allRewards;
        });
  }

  // Get all rewards for a department (without stock filter)
  Stream<List<RewardModel>> getAllRewardsStream(String department) {
    return _firestore
        .collection('rewards')
        .where('department', isEqualTo: department)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => RewardModel.fromMap(doc.data(), doc.id))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  // Get current user's student data
  Future<StudentModel?> getCurrentStudent() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('students').doc(user.uid).get();
    if (!doc.exists) return null;

    return StudentModel.fromMap(doc.data()!, doc.id);
  }

  // Redeem a reward
  Future<String> redeemReward(RewardModel reward) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'User not authenticated';
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        final studentDoc = await transaction.get(
          _firestore.collection('students').doc(user.uid),
        );

        if (!studentDoc.exists) {
          throw Exception('Student data not found');
        }

        final student = StudentModel.fromMap(studentDoc.data()!, studentDoc.id);

        if (student.points < reward.cost) {
          throw Exception(
            'Insufficient points. You need ${reward.cost} points but only have ${student.points}.',
          );
        }

        final rewardDoc = await transaction.get(
          _firestore.collection('rewards').doc(reward.id),
        );

        if (!rewardDoc.exists) {
          throw Exception('Reward not found');
        }

        final currentReward = RewardModel.fromMap(
          rewardDoc.data()!,
          rewardDoc.id,
        );

        if (currentReward.stock <= 0) {
          throw Exception('Reward is out of stock');
        }

        transaction.update(_firestore.collection('students').doc(user.uid), {
          'points': student.points - reward.cost,
          'totalPointsSpent': FieldValue.increment(reward.cost),
          'totalRewardsRedeemed': FieldValue.increment(1),
        });

        transaction.update(_firestore.collection('rewards').doc(reward.id), {
          'stock': currentReward.stock - 1,
        });

        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(
          transactionRef,
          TransactionModel(
            id: transactionRef.id,
            userId: user.uid,
            studentName: student.fullName,
            rewardId: reward.id,
            rewardName: reward.name,
            points: reward.cost,
            type: 'redeem',
            department: student.department,
            status: 'Pending',
            ticketCode: TransactionModel.generateTicketCode(),
          ).toMap(),
        );

        return 'Reward redeemed successfully!';
      });
    } catch (e) {
      return 'Failed to redeem reward: ${e.toString()}';
    }
  }

  // Get user's transaction history
  Stream<List<TransactionModel>> getUserTransactionsStream(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }
}
