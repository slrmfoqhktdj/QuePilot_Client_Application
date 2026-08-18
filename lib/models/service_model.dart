/// ═══════════════════════════════════════════
/// 1:1 직접 통화 이벤트
/// ═══════════════════════════════════════════

class IncomingDirectCallEvent {
  final String callId;
  final String callerId;
  final String callerName;

  IncomingDirectCallEvent({
    required this.callId,
    required this.callerId,
    required this.callerName,
  });

  factory IncomingDirectCallEvent.fromJson(Map<String, dynamic> data) {
    return IncomingDirectCallEvent(
      callId: data['callId'] as String? ?? '',
      callerId: data['callerId'] as String? ?? '',
      callerName: data['callerName'] as String? ?? 'Unknown',
    );
  }
}

class DirectCallCancelledEvent {
  final String callId;
  final String callerId;
  final String callerName;

  DirectCallCancelledEvent({
    required this.callId,
    required this.callerId,
    required this.callerName,
  });

  factory DirectCallCancelledEvent.fromJson(Map<String, dynamic> data) {
    return DirectCallCancelledEvent(
      callId: data['callId'] as String? ?? '',
      callerId: data['callerId'] as String? ?? '',
      callerName: data['callerName'] as String? ?? 'Unknown',
    );
  }
}

class DirectCallEndedEvent {
  final String callId;
  final String endedBy;
  final String endedByName;
  final String? reason;

  DirectCallEndedEvent({
    required this.callId,
    required this.endedBy,
    required this.endedByName,
    this.reason,
  });

  factory DirectCallEndedEvent.fromJson(Map<String, dynamic> data) {
    return DirectCallEndedEvent(
      callId: data['callId'] as String? ?? '',
      endedBy: data['endedBy'] as String? ?? '',
      endedByName: data['endedByName'] as String? ?? 'Unknown',
      reason: data['reason'] as String?,
    );
  }
}

/// ═══════════════════════════════════════════
/// Direct WebRTC 시그널링
/// ═══════════════════════════════════════════

class DirectWebRTCEvent {
  final String callId;
  final String from;
  final dynamic payload; // offer / answer / candidate

  DirectWebRTCEvent({
    required this.callId,
    required this.from,
    required this.payload,
  });

  factory DirectWebRTCEvent.fromJson(Map<String, dynamic> data, String payloadKey) {
    return DirectWebRTCEvent(
      callId: data['callId'] as String? ?? '',
      from: data['from'] as String? ?? '',
      payload: data[payloadKey],
    );
  }
}

/// ═══════════════════════════════════════════
/// 유저 입퇴장
/// ═══════════════════════════════════════════

class RoomUserEvent {
  final String userId;
  final String userName;
  final int totalMembers;
  final DateTime timestamp;

  RoomUserEvent({
    required this.userId,
    required this.userName,
    required this.totalMembers,
    required this.timestamp,
  });

  factory RoomUserEvent.fromJson(Map<String, dynamic> data) {
    return RoomUserEvent(
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      totalMembers: data['totalMembers'] as int? ?? 0,
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String).toLocal()
          : DateTime.now().toLocal(),
    );
  }
}

/// ═══════════════════════════════════════════
/// 방 CRUD
/// ═══════════════════════════════════════════

class RoomCreatedEvent {
  final String roomId;
  final String roomName;
  final DateTime createdAt;

  RoomCreatedEvent({
    required this.roomId,
    required this.roomName,
    required this.createdAt,
  });

  factory RoomCreatedEvent.fromJson(Map<String, dynamic> data) {
    return RoomCreatedEvent(
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String).toLocal()
          : DateTime.now().toLocal(),
    );
  }
}

class RoomUpdatedEvent {
  final String roomId;
  final String roomName;

  RoomUpdatedEvent({
    required this.roomId,
    required this.roomName,
  });

  factory RoomUpdatedEvent.fromJson(Map<String, dynamic> data) {
    return RoomUpdatedEvent(
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
    );
  }
}

class RoomDeletedEvent {
  final String roomId;

  RoomDeletedEvent({required this.roomId});

  factory RoomDeletedEvent.fromJson(Map<String, dynamic> data) {
    return RoomDeletedEvent(
      roomId: data['roomId'] as String? ?? '',
    );
  }
}

/// ═══════════════════════════════════════════
/// 방 통화
/// ═══════════════════════════════════════════

class CallParticipant {
  final String oderId;
  final String odername;
  final bool isMuted;

  CallParticipant({
    required this.oderId,
    required this.odername,
    required this.isMuted,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> data) {
    return CallParticipant(
      oderId: data['userId'] as String? ?? '',
      odername: data['userName'] as String? ?? '',
      isMuted: data['isMuted'] as bool? ?? false,
    );
  }
}

class CallParticipantsEvent {
  final List<CallParticipant> participants;
  final int totalParticipants;

  CallParticipantsEvent({
    required this.participants,
    required this.totalParticipants,
  });

  factory CallParticipantsEvent.fromJson(Map<String, dynamic> data) {
    final list = (data['participants'] as List<dynamic>?)
        ?.map((e) => CallParticipant.fromJson(Map<String, dynamic>.from(e)))
        .toList() ??
        [];
    return CallParticipantsEvent(
      participants: list,
      totalParticipants: data['totalParticipants'] as int? ?? list.length,
    );
  }
}

class CallUserEvent {
  final String userId;
  final String username;

  CallUserEvent({
    required this.userId,
    required this.username,
  });

  factory CallUserEvent.fromJson(Map<String, dynamic> data) {
    return CallUserEvent(
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? '',
    );
  }
}

class PeerMuteEvent {
  final String userId;
  final bool isMuted;

  PeerMuteEvent({
    required this.userId,
    required this.isMuted,
  });

  factory PeerMuteEvent.fromJson(Map<String, dynamic> data) {
    return PeerMuteEvent(
      userId: data['userId'] as String? ?? '',
      isMuted: data['isMuted'] as bool? ?? false,
    );
  }
}

/// ═══════════════════════════════════════════
/// Room WebRTC 시그널링
/// ═══════════════════════════════════════════

class RoomWebRTCEvent {
  final String from;
  final dynamic payload; // offer / answer / candidate

  RoomWebRTCEvent({
    required this.from,
    required this.payload,
  });

  factory RoomWebRTCEvent.fromJson(Map<String, dynamic> data, String payloadKey) {
    return RoomWebRTCEvent(
      from: data['from'] as String? ?? '',
      payload: data[payloadKey],
    );
  }
}

/// ═══════════════════════════════════════════
/// 트랙
/// ═══════════════════════════════════════════

class TrackEvent {
  final Map<String, dynamic> track;

  TrackEvent({required this.track});

  factory TrackEvent.fromJson(Map<String, dynamic> data) {
    return TrackEvent(
      track: Map<String, dynamic>.from(data['track'] ?? data),
    );
  }
}

class TrackDeletedEvent {
  final String trackId;

  TrackDeletedEvent({required this.trackId});

  factory TrackDeletedEvent.fromJson(Map<String, dynamic> data) {
    return TrackDeletedEvent(
      trackId: data['trackId'] as String? ?? '',
    );
  }
}

/// ═══════════════════════════════════════════
/// 권한 업데이트
/// ═══════════════════════════════════════════

class PermissionUpdatedEvent {
  final List<String> updateRoomIds;
  final List<String> deleteRoomIds;
  final DateTime timestamp;

  PermissionUpdatedEvent({
    required this.updateRoomIds,
    required this.deleteRoomIds,
    required this.timestamp,
  });

  factory PermissionUpdatedEvent.fromJson(Map<String, dynamic> data) {
    return PermissionUpdatedEvent(
      updateRoomIds: List<String>.from(data['updateRoomIds'] ?? []),
      deleteRoomIds: List<String>.from(data['deleteRoomIds'] ?? []),
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'] as String).toLocal()
          : DateTime.now().toLocal(),
    );
  }
}

/// ═══════════════════════════════════════════
/// 재생 제어
/// ═══════════════════════════════════════════

class PlaybackEvent {
  final Map<String, dynamic> raw;

  PlaybackEvent({required this.raw});

  factory PlaybackEvent.fromJson(Map<String, dynamic> data) {
    return PlaybackEvent(raw: data);
  }
}