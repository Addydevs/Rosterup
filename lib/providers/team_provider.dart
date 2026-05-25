import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/team.dart';
import '../services/analytics_service.dart';

class TeamProvider extends ChangeNotifier {
  // Access Firestore lazily so the provider can be used
  // without requiring Firebase.initializeApp() during local-only prototyping.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  
  List<Team> _teams = [];
  bool _isLoading = false;
  String? _error;

  List<Team> get teams => _teams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> renameTeam({
    required String teamId,
    required String newName,
    required String requesterId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final index = _teams.indexWhere((t) => t.id == teamId);
      if (index == -1) {
        _error = 'Team not found';
        return false;
      }

      final team = _teams[index];
      final isAdmin = team.adminId == requesterId;
      if (!isAdmin) {
        _error = 'Only admins can rename the team';
        return false;
      }

      final trimmedName = newName.trim();
      if (trimmedName.isEmpty) {
        _error = 'Team name cannot be empty';
        return false;
      }

      await _firestore.collection('teams').doc(teamId).update({
        'name': trimmedName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _teams[index] = team.copyWith(name: trimmedName);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> createTeam({
    required String name,
    required Sport sport,
    required String adminId,
    required String location,
    String? customSportName,
    RecurringSchedule? recurringSchedule,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Generate unique 6-character team code
      String teamCode;
      bool codeExists = true;
      
      do {
        teamCode = _generateTeamCode();
        final existingTeam = await _firestore
            .collection('teams')
            .where('teamCode', isEqualTo: teamCode)
            .get();
        codeExists = existingTeam.docs.isNotEmpty;
      } while (codeExists);

      final team = Team(
        id: _uuid.v4(),
        name: name,
        sport: sport,
        adminId: adminId,
        teamCode: teamCode,
        memberIds: [adminId], // Admin is automatically a member
        location: location,
        customSportName: customSportName,
        recurringSchedule: recurringSchedule,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('teams').doc(team.id).set(team.toFirestore());
      
      _teams.add(team);
      // Analytics: team created (do not fail creation if analytics throws)
      try {
        await AnalyticsService.logCreateTeam(
          teamId: team.id,
          sport: sport.name,
          hasCustomSport: (customSportName ?? '').isNotEmpty,
        );
      } catch (e) {
        // Record analytics error but don't break the user flow
        _error = e.toString();
      }
      return team.id;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> joinTeam(String teamCode, String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final teamQuery = await _firestore
          .collection('teams')
          .where('teamCode', isEqualTo: teamCode.toUpperCase())
          .limit(1)
          .get();

      if (teamQuery.docs.isEmpty) {
        _error = 'Team not found';
        return false;
      }

      final teamRef = teamQuery.docs.first.reference;
      Team? updatedTeam;

      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(teamRef);
        final members =
            List<String>.from(snap.data()?['memberIds'] ?? []);
        if (members.contains(userId)) {
          throw Exception('already_member');
        }
        txn.update(teamRef, {
          'memberIds': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final freshTeam = Team.fromFirestore(snap);
        updatedTeam = freshTeam.copyWith(
          memberIds: [...freshTeam.memberIds, userId],
        );
      });

      if (updatedTeam != null) {
        final index = _teams.indexWhere((t) => t.id == updatedTeam!.id);
        if (index != -1) {
          _teams[index] = updatedTeam!;
        } else {
          _teams.add(updatedTeam!);
        }
      }

      return true;
    } catch (e) {
      if (e.toString().contains('already_member')) {
        _error = 'You are already a member of this team';
      } else {
        _error = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserTeams(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('teams')
          .where('memberIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      _teams = snapshot.docs.map((doc) => Team.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setRecurringSchedule({
    required String teamId,
    required Map<int, TimeOfDay> dayTimes,
  }) async {
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index == -1) return;

    final slots = dayTimes.entries
        .map(
          (entry) => RecurringSlot(
            dayOfWeek: entry.key,
            time: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    final schedule = RecurringSchedule(slots: slots);

    try {
      await _firestore.collection('teams').doc(teamId).update({
        'recurringSchedule': schedule.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _teams[index] = _teams[index].copyWith(recurringSchedule: schedule);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> deleteTeam({
    required String teamId,
    required String requesterId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final index = _teams.indexWhere((t) => t.id == teamId);
      if (index == -1) {
        _error = 'Team not found';
        return false;
      }

      final team = _teams[index];
      final isAdmin = team.adminId == requesterId;
      if (!isAdmin) {
        _error = 'Only admins can delete the team';
        return false;
      }

      await _firestore.collection('teams').doc(teamId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _teams[index] = team.copyWith(isActive: false);
      _teams = _teams.where((t) => t.isActive).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> leaveTeam({
    required String teamId,
    required String userId,
  }) {
    return removeMember(
      teamId: teamId,
      memberId: userId,
      requesterId: userId,
    );
  }

  Future<bool> removeMember({
    required String teamId,
    required String memberId,
    required String requesterId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final index = _teams.indexWhere((t) => t.id == teamId);
      if (index == -1) {
        _error = 'Team not found';
        return false;
      }

      final team = _teams[index];
      final isAdmin = team.adminId == requesterId;
      if (!isAdmin && requesterId != memberId) {
        _error = 'Only admins can remove other members';
        return false;
      }

      if (memberId == team.adminId && requesterId == memberId) {
        _error = 'Admin cannot remove themselves';
        return false;
      }

      await _firestore.collection('teams').doc(teamId).update({
        'memberIds': FieldValue.arrayRemove([memberId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedMembers =
          team.memberIds.where((id) => id != memberId).toList();
      _teams[index] = team.copyWith(memberIds: updatedMembers);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> muteMember({
    required String teamId,
    required String memberId,
    required String requesterId,
    required bool muted,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final index = _teams.indexWhere((t) => t.id == teamId);
      if (index == -1) {
        _error = 'Team not found';
        return false;
      }

      final team = _teams[index];
      final isAdmin = team.adminId == requesterId;
      if (!isAdmin) {
        _error = 'Only admins can mute members';
        return false;
      }

      if (!team.memberIds.contains(memberId)) {
        _error = 'User is not a member of this team';
        return false;
      }

      if (memberId == team.adminId) {
        _error = 'Admin cannot be muted';
        return false;
      }

      if (muted) {
        await _firestore.collection('teams').doc(teamId).update({
          'mutedMemberIds': FieldValue.arrayUnion([memberId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final updatedMuted = {...team.mutedMemberIds, memberId}.toList();
        _teams[index] = team.copyWith(mutedMemberIds: updatedMuted);
      } else {
        await _firestore.collection('teams').doc(teamId).update({
          'mutedMemberIds': FieldValue.arrayRemove([memberId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final updatedMuted =
            team.mutedMemberIds.where((id) => id != memberId).toList();
        _teams[index] = team.copyWith(mutedMemberIds: updatedMuted);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static final _rng = Random.secure();

  String _generateTeamCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing chars
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[_rng.nextInt(chars.length)];
    }
    return code;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Team?> findTeamByCode(String teamCode) async {
    try {
      final teamQuery = await _firestore
          .collection('teams')
          .where('teamCode', isEqualTo: teamCode.toUpperCase())
          .get();

      if (teamQuery.docs.isEmpty) {
        return null;
      }

      return Team.fromFirestore(teamQuery.docs.first);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
