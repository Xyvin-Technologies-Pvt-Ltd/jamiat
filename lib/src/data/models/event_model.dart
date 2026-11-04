class EventPerson {
  const EventPerson({
    required this.name,
    this.id,
    this.designation,
    this.image,
  });

  final String? id;
  final String name;
  final String? designation;
  final String? image;

  factory EventPerson.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image'] ?? json['profile_image'] ?? json['photo'];
    final image = rawImage?.toString().trim();
    return EventPerson(
      id: (json['_id'] ?? json['id'])?.toString(),
      name: (json['name'] ?? '').toString().trim(),
      designation: json['designation']?.toString().trim(),
      image: (image == null || image.isEmpty || image == 'null') ? null : image,
    );
  }
}

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.isBookmarked,
    this.status = 'draft',
    this.coverImage,
    this.startDate,
    this.endDate,
    this.venue,
    this.onlineLink,
    this.registrationEnabled,
    this.isRegistered,
    this.myTicketId,
    this.guests = const [],
    this.coordinators = const [],
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final bool isBookmarked;

  /// Backend: draft | published | completed | deleted
  final String status;
  final String? coverImage;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? venue;
  final String? onlineLink;
  final bool? registrationEnabled;
  final bool? isRegistered;
  final String? myTicketId;
  final List<EventPerson> guests;
  final List<EventPerson> coordinators;

  bool isCoordinator(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return coordinators.any((c) => c.id == userId);
  }

  /// True when the event's calendar day (or multi-day range) is over.
  ///
  /// Uses [endDate] when it is on/after [startDate] (ongoing multi-day events).
  /// Falls back to [startDate] when end is missing or before start.
  bool get hasEnded {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final start = startDate?.toLocal();
    final end = endDate?.toLocal();

    DateTime? lastMoment;
    if (start != null && end != null) {
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      // Valid range (including multi-week events like Nov 4–25).
      if (!endDay.isBefore(startDay)) {
        lastMoment = end.isAfter(start) ? end : start;
      } else {
        // End before start → treat as single-day on start
        lastMoment = start;
      }
    } else {
      lastMoment = end ?? start;
    }

    if (lastMoment == null) return false;

    final lastDay = DateTime(
      lastMoment.year,
      lastMoment.month,
      lastMoment.day,
    );
    if (lastDay.isBefore(today)) return true;
    if (lastDay.isAfter(today)) return false;

    final hasClockTime =
        lastMoment.hour != 0 ||
        lastMoment.minute != 0 ||
        lastMoment.second != 0;
    final cutoff = hasClockTime
        ? lastMoment
        : DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999);
    return now.isAfter(cutoff);
  }

  /// Hide from user-facing lists (completed / deleted API status).
  bool get isHiddenFromListing {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'deleted':
        return true;
      default:
        return false;
    }
  }

  /// Finished for UX: API marked completed, or calendar window is over.
  bool get isFinished =>
      status.toLowerCase() == 'completed' || hasEnded;

  static String _parseStatus(dynamic raw) {
    if (raw == null) return 'draft';
    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'null') return 'draft';
    return value;
  }

  /// Parses API dates and returns device-local wall time so UI matches admin.
  static DateTime? parseApiDate(dynamic raw) {
    if (raw == null) return null;
    DateTime? parsed;
    if (raw is DateTime) {
      parsed = raw;
    } else if (raw is int) {
      // Heuristic: seconds vs milliseconds
      final ms = raw < 100000000000 ? raw * 1000 : raw;
      parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } else if (raw is num) {
      return parseApiDate(raw.toInt());
    } else if (raw is Map) {
      final nested = raw[r'$date'] ?? raw['date'];
      return parseApiDate(nested);
    } else {
      final text = raw.toString().trim();
      if (text.isEmpty || text == 'null') return null;
      final asInt = int.tryParse(text);
      if (asInt != null && text.length >= 9) {
        return parseApiDate(asInt);
      }
      parsed = DateTime.tryParse(text);
    }
    return parsed?.toLocal();
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final guestsRaw = json['guests'];
    final coordinatorsRaw = json['coordinators'];

    List<EventPerson> parsePeople(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) {
            if (e is Map) {
              return EventPerson.fromJson(Map<String, dynamic>.from(e));
            }
            // Unpopulated ObjectId string
            if (e != null) {
              return EventPerson(id: e.toString(), name: '');
            }
            return null;
          })
          .whereType<EventPerson>()
          .where((p) => p.id != null || p.name.isNotEmpty)
          .toList();
    }

    return EventModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      type: (json['event_type'] ?? json['type'] ?? 'Offline').toString(),
      isBookmarked: json['is_bookmarked'] == true,
      status: _parseStatus(json['status']),
      coverImage: json['cover_image']?.toString(),
      startDate: parseApiDate(
        json['start_date'] ?? json['startDate'] ?? json['event_date'] ?? json['date'],
      ),
      endDate: parseApiDate(
        json['end_date'] ?? json['endDate'],
      ),
      venue: json['venue']?.toString(),
      onlineLink: (json['link'] ?? json['online_link'])?.toString(),
      registrationEnabled: () {
        final required = json['registration_required'];
        if (required is bool) return required;
        final enabled = json['registration_enabled'];
        if (enabled is bool) return enabled;
        return true;
      }(),
      isRegistered: json['is_registered'] == true,
      myTicketId: json['my_ticket_id']?.toString(),
      guests: parsePeople(guestsRaw)
          .where((p) => p.name.isNotEmpty)
          .toList(),
      coordinators: parsePeople(coordinatorsRaw),
    );
  }
}

class EventTicketModel {
  const EventTicketModel({
    required this.id,
    required this.ticketCode,
    required this.status,
    this.displayStatus,
    this.qrImage,
    this.qrToken,
    this.eventId,
    this.eventTitle,
    this.eventDate,
    this.eventEndDate,
    this.venue,
    this.passType = 'General Entry Pass',
  });

  final String id;
  final String ticketCode;
  final String status;
  final String? displayStatus;
  final String? qrImage;
  final String? qrToken;
  final String? eventId;
  final String? eventTitle;
  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final String? venue;
  final String passType;

  bool get isAttended =>
      displayStatus == 'attended' || status == 'attended';

  bool get isMissed =>
      displayStatus == 'missed' || status == 'missed';

  factory EventTicketModel.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    final eventMap = event is Map
        ? Map<String, dynamic>.from(event)
        : <String, dynamic>{};

    return EventTicketModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      ticketCode: (json['ticket_code'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      displayStatus: json['display_status']?.toString(),
      qrImage: json['qr_image']?.toString(),
      qrToken: json['qr_token']?.toString(),
      eventId: (eventMap['_id'] ?? eventMap['id'])?.toString(),
      eventTitle: eventMap['title']?.toString(),
      eventDate: EventModel.parseApiDate(eventMap['start_date']),
      eventEndDate: EventModel.parseApiDate(eventMap['end_date']),
      venue: eventMap['venue']?.toString(),
      passType: (json['pass_type'] ?? 'General Entry Pass').toString(),
    );
  }
}

class EventScanResult {
  const EventScanResult({
    required this.alreadyAttended,
    required this.ticketCode,
    this.attendedAt,
    this.attendeeName,
    this.eventTitle,
    this.message,
  });

  final bool alreadyAttended;
  final String ticketCode;
  final DateTime? attendedAt;
  final String? attendeeName;
  final String? eventTitle;
  final String? message;

  factory EventScanResult.fromJson(
    Map<String, dynamic> json, {
    String? message,
  }) {
    final user = json['user'];
    final userMap = user is Map
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{};
    final event = json['event'];
    final eventMap = event is Map
        ? Map<String, dynamic>.from(event)
        : <String, dynamic>{};

    return EventScanResult(
      alreadyAttended: json['already_attended'] == true,
      ticketCode: (json['ticket_code'] ?? '').toString(),
      attendedAt: json['attended_at'] != null
          ? DateTime.tryParse(json['attended_at'].toString())
          : null,
      attendeeName: userMap['name']?.toString(),
      eventTitle: eventMap['title']?.toString(),
      message: message,
    );
  }
}
