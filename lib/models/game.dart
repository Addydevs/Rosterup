import 'package:cloud_firestore/cloud_firestore.dart';

enum ConfirmationStatus {
  confirmed('I\'m In', '✅'),
  declined('I\'m Out', '❌'), 
  maybe('Maybe', '⚠️'),
  noResponse('No Response', '⏳');

  const ConfirmationStatus(this.label, this.icon);
  final String label;
  final String icon;
}

class Game {
  final String id;
  final String teamId;
  final DateTime dateTime;
  final String location;
  final String? locationUrl; // Google Maps link
  final double? latitude;
  final double? longitude;
  final int? maxPlayersIn;
  final bool isRecurring;
  final bool isPublic;
  final String? accessCode;
  final Map<String, ConfirmationStatus> confirmations; // userId -> status
  final Map<String, int> guestCounts; // userId -> extra guests (e.g. plus ones)
  final Map<String, String> declineReasons; // userId -> reason code
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? notes;

  Game({
    required this.id,
    required this.teamId,
    required this.dateTime,
    required this.location,
    this.locationUrl,
    this.latitude,
    this.longitude,
    this.maxPlayersIn,
    this.isRecurring = false,
    this.isPublic = true,
    this.accessCode,
    required this.confirmations,
    Map<String, int>? guestCounts,
    Map<String, String>? declineReasons,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.notes,
  })  : guestCounts = guestCounts ?? const {},
        declineReasons = declineReasons ?? const {};

  factory Game.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Convert confirmations map
    final confirmationsData = data['confirmations'] as Map<String, dynamic>? ?? {};
    final confirmations = <String, ConfirmationStatus>{};
    
    confirmationsData.forEach((userId, statusName) {
      final status = ConfirmationStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => ConfirmationStatus.noResponse,
      );
      confirmations[userId] = status;
    });

    // Convert guestCounts map (userId -> int)
    final guestCountsData = data['guestCounts'] as Map<String, dynamic>? ?? {};
    final guestCounts = <String, int>{};
    guestCountsData.forEach((userId, value) {
      if (value is int) {
        guestCounts[userId] = value;
      }
    });

    // Decline reasons (userId -> String)
    final declineReasonsData =
        data['declineReasons'] as Map<String, dynamic>? ?? {};
    final declineReasons = <String, String>{};
    declineReasonsData.forEach((userId, value) {
      if (value is String && value.isNotEmpty) {
        declineReasons[userId] = value;
      }
    });

    return Game(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'] ?? '',
      locationUrl: data['locationUrl'],
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      maxPlayersIn: data['maxPlayersIn'] as int?,
      isRecurring: data['isRecurring'] ?? false,
      isPublic: data['isPublic'] ?? true,
      accessCode: data['accessCode'],
      confirmations: confirmations,
      guestCounts: guestCounts,
      declineReasons: declineReasons,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    // Convert confirmations to Firestore format
    final confirmationsData = <String, String>{};
    confirmations.forEach((userId, status) {
      confirmationsData[userId] = status.name;
    });

    // Guest counts map (userId -> int)
    final guestCountsData = <String, int>{};
    guestCounts.forEach((userId, count) {
      if (count > 0) {
        guestCountsData[userId] = count;
      }
    });

    // Decline reasons
    final declineReasonsData = <String, String>{};
    declineReasons.forEach((userId, reason) {
      if (reason.isNotEmpty) {
        declineReasonsData[userId] = reason;
      }
    });

    return {
      'teamId': teamId,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'locationUrl': locationUrl,
      'latitude': latitude,
      'longitude': longitude,
      'maxPlayersIn': maxPlayersIn,
      'isRecurring': isRecurring,
      'isPublic': isPublic,
      'accessCode': accessCode,
      'confirmations': confirmationsData,
      'guestCounts': guestCountsData,
      'declineReasons': declineReasonsData,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'notes': notes,
    };
  }

  // Helper methods
  List<String> getPlayersWithStatus(ConfirmationStatus status) {
    return confirmations.entries
        .where((entry) => entry.value == status)
        .map((entry) => entry.key)
        .toList();
  }

  int getConfirmedCount() => getPlayersWithStatus(ConfirmationStatus.confirmed).length;
  int getDeclinedCount() => getPlayersWithStatus(ConfirmationStatus.declined).length;
  int getMaybeCount() => getPlayersWithStatus(ConfirmationStatus.maybe).length;
  int getNoResponseCount() => getPlayersWithStatus(ConfirmationStatus.noResponse).length;

  int getTotalGuestCount() {
    if (guestCounts.isEmpty) return 0;
    return guestCounts.values.fold(0, (sum, value) => sum + value);
  }

  double getConfirmationRate() {
    if (confirmations.isEmpty) return 0.0;
    return getConfirmedCount() / confirmations.length;
  }

  bool get hasEnoughPlayers => getConfirmedCount() >= 8; // Minimum for most sports

  Game copyWith({
    String? teamId,
    DateTime? dateTime,
    String? location,
    String? locationUrl,
    double? latitude,
    double? longitude,
    int? maxPlayersIn,
    bool? isRecurring,
    bool? isPublic,
    String? accessCode,
    Map<String, ConfirmationStatus>? confirmations,
    Map<String, int>? guestCounts,
    Map<String, String>? declineReasons,
    bool? isActive,
    String? notes,
  }) {
    return Game(
      id: id,
      teamId: teamId ?? this.teamId,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      locationUrl: locationUrl ?? this.locationUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      maxPlayersIn: maxPlayersIn ?? this.maxPlayersIn,
      isRecurring: isRecurring ?? this.isRecurring,
      isPublic: isPublic ?? this.isPublic,
      accessCode: accessCode ?? this.accessCode,
      confirmations: confirmations ?? this.confirmations,
      guestCounts: guestCounts ?? this.guestCounts,
      declineReasons: declineReasons ?? this.declineReasons,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}
