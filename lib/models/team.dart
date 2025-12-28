import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum Sport {
  football('Soccer', '⚽'),
  basketball('Basketball', '🏀'),
  americanFootball('American Football', '🏈'),
  tennis('Tennis', '🎾'),
  volleyball('Volleyball', '🏐'),
  pickleball('Pickleball', '🏓'),
  other('Other', '⭐');

  const Sport(this.label, this.emoji);
  final String label;
  final String emoji;
}

class Team {
  final String id;
  final String name;
  final Sport sport;
  final String adminId;
  final String teamCode; // 6-character code like "WMH8KQ"
  final List<String> memberIds;
  final String location;
  final String? customSportName;
  final List<String> mutedMemberIds;
  final RecurringSchedule? recurringSchedule;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Team({
    required this.id,
    required this.name,
    required this.sport,
    required this.adminId,
    required this.teamCode,
    required this.memberIds,
    required this.location,
    this.customSportName,
    this.mutedMemberIds = const [],
    this.recurringSchedule,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      sport: Sport.values.firstWhere(
        (s) => s.name == data['sport'],
        orElse: () => Sport.basketball,
      ),
      adminId: data['adminId'] ?? '',
      teamCode: data['teamCode'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      location: data['location'] ?? '',
      customSportName: data['customSportName'],
      mutedMemberIds: List<String>.from(data['mutedMemberIds'] ?? []),
      recurringSchedule: data['recurringSchedule'] != null 
        ? RecurringSchedule.fromMap(data['recurringSchedule'])
        : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sport': sport.name,
      'adminId': adminId,
      'teamCode': teamCode,
      'memberIds': memberIds,
      'location': location,
      'customSportName': customSportName,
      'mutedMemberIds': mutedMemberIds,
      'recurringSchedule': recurringSchedule?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  Team copyWith({
    String? name,
    Sport? sport,
    String? adminId,
    String? teamCode,
    List<String>? memberIds,
    String? location,
    String? customSportName,
     List<String>? mutedMemberIds,
    RecurringSchedule? recurringSchedule,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      adminId: adminId ?? this.adminId,
      teamCode: teamCode ?? this.teamCode,
      memberIds: memberIds ?? this.memberIds,
      location: location ?? this.location,
      customSportName: customSportName ?? this.customSportName,
      mutedMemberIds: mutedMemberIds ?? this.mutedMemberIds,
      recurringSchedule: recurringSchedule ?? this.recurringSchedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }
}

class RecurringSlot {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final TimeOfDay time;

  RecurringSlot({
    required this.dayOfWeek,
    required this.time,
  });

  factory RecurringSlot.fromMap(Map<String, dynamic> map) {
    return RecurringSlot(
      dayOfWeek: map['dayOfWeek'] ?? 1,
      time: TimeOfDay(
        hour: map['hour'] ?? 0,
        minute: map['minute'] ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'hour': time.hour,
      'minute': time.minute,
    };
  }
}

class RecurringSchedule {
  final List<RecurringSlot> slots;

  RecurringSchedule({
    required this.slots,
  });

  factory RecurringSchedule.fromMap(Map<String, dynamic> map) {
    // New format: { slots: [ { dayOfWeek, hour, minute }, ... ] }
    if (map['slots'] is List) {
      final rawSlots = map['slots'] as List<dynamic>;
      return RecurringSchedule(
        slots: rawSlots
            .map((s) => RecurringSlot.fromMap(
                  Map<String, dynamic>.from(s as Map),
                ))
            .toList(),
      );
    }

    // Backwards-compat: old format { daysOfWeek: [...], hour, minute }
    final days = List<int>.from(map['daysOfWeek'] ?? []);
    final time = TimeOfDay(
      hour: map['hour'] ?? 0,
      minute: map['minute'] ?? 0,
    );

    return RecurringSchedule(
      slots: days
          .map(
            (d) => RecurringSlot(
              dayOfWeek: d,
              time: time,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slots': slots.map((s) => s.toMap()).toList(),
    };
  }
}
