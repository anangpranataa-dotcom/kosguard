import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

enum ItemStatus { active, retrieved, expired }

class KGUser {
  final int id;
  final String name;
  final String email;
  final String roomNumber;
  final String propertyName;
  final String role;
  final int? roomId;

  const KGUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roomNumber,
    this.propertyName = 'Kost Kemuning',
    this.role = 'resident',
    this.roomId,
  });

  bool get isOwner =>
      role == 'property_owner' || email.toLowerCase().contains('owner');

  factory KGUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const KGUser(
        id: 0,
        name: 'Penghuni kost',
        email: '',
        roomNumber: '08',
      );
    }

    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;

    final name = json['name']?.toString() ?? 'Penghuni kost';
    final email = json['email']?.toString() ?? '';
    final role = json['role']?.toString() ?? 'resident';

    String roomNumber = '08';
    if (json['room_number'] != null) {
      roomNumber = json['room_number'].toString();
    } else if (json['room'] != null) {
      if (json['room'] is Map) {
        roomNumber = json['room']['room_number']?.toString() ??
            json['room']['number']?.toString() ??
            '08';
      } else {
        roomNumber = json['room'].toString();
      }
    }

    final propertyName = json['property_name']?.toString() ??
        (json['property'] is Map
            ? json['property']['name']?.toString()
            : null) ??
        (json['kost_name']?.toString() ?? 'Kost Kemuning');

    final roomId = json['room_id'] is int
        ? json['room_id'] as int
        : int.tryParse(json['room_id']?.toString() ?? '');

    return KGUser(
      id: id,
      name: name,
      email: email,
      roomNumber: roomNumber,
      propertyName: propertyName,
      role: role,
      roomId: roomId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'room_number': roomNumber,
        'property_name': propertyName,
        'role': role,
        'room_id': roomId,
      };
}

class ItemActivity {
  const ItemActivity({
    this.id,
    required this.itemName,
    required this.oldStatus,
    required this.newStatus,
    required this.occurredAt,
    required this.facility,
    required this.room,
    required this.actor,
    this.isSample = false,
  });

  final int? id;
  final String itemName;
  final String oldStatus;
  final String newStatus;
  final DateTime occurredAt;
  final String facility;
  final String room;
  final String actor;
  final bool isSample;

  factory ItemActivity.fromJson(
    Map<String, dynamic>? json, {
    String defaultItemName = 'Barang',
    String defaultFacility = 'Ruang bersama',
    String defaultRoom = '08',
  }) {
    if (json == null) {
      return ItemActivity(
        itemName: defaultItemName,
        oldStatus: '—',
        newStatus: 'ACTIVE',
        occurredAt: DateTime.now(),
        facility: defaultFacility,
        room: defaultRoom,
        actor: 'Penghuni',
      );
    }

    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '');

    final itemName = json['item_name']?.toString() ??
        (json['item'] is Map ? json['item']['name']?.toString() : null) ??
        defaultItemName;

    final oldStatus = json['old_status']?.toString() ?? '—';
    final newStatus = json['new_status']?.toString() ??
        (json['status']?.toString() ?? 'ACTIVE');

    DateTime occurredAt = DateTime.now();
    if (json['occurred_at'] != null) {
      occurredAt = DateTime.tryParse(json['occurred_at'].toString())?.toLocal() ??
          occurredAt;
    } else if (json['created_at'] != null) {
      occurredAt = DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
          occurredAt;
    }

    final facility = json['facility']?.toString() ??
        (json['item'] is Map ? json['item']['facility']?.toString() : null) ??
        defaultFacility;

    final room = json['room']?.toString() ??
        json['room_number']?.toString() ??
        (json['item'] is Map
            ? json['item']['room_number']?.toString()
            : null) ??
        defaultRoom;

    final actor = json['actor']?.toString() ??
        (json['user'] is Map ? json['user']['name']?.toString() : null) ??
        (json['changed_by_name']?.toString() ?? 'Penghuni');

    return ItemActivity(
      id: id,
      itemName: itemName,
      oldStatus: oldStatus,
      newStatus: newStatus,
      occurredAt: occurredAt,
      facility: facility,
      room: room,
      actor: actor,
      isSample: false,
    );
  }
}

class KGItem {
  KGItem({
    this.id,
    required this.name,
    required this.category,
    required this.facility,
    required this.room,
    required this.remaining,
    required this.icon,
    required this.artBg,
    required this.artColor,
    this.photoPath,
    this.photoUrl,
    this.photoBytes,
    this.userId,
    this.isMine = false,
    required this.status,
    this.rawStatus = 'ACTIVE',
    this.expiresAt,
    this.createdAt,
    this.color,
    this.brand,
    this.distinctiveMarks,
    this.activities = const [],
  });

  final int? id;
  String name;
  String category;
  String facility;
  final String room;
  String remaining;
  final IconData icon;
  final Color artBg;
  final Color artColor;
  final String? photoPath;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final int? userId;
  final bool isMine;
  ItemStatus status;
  String rawStatus;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  String? color;
  String? brand;
  String? distinctiveMarks;
  final List<ItemActivity> activities;

  bool get isExpired =>
      rawStatus.toUpperCase() == 'EXPIRED' || remaining == 'Sesi habis';

  bool get canReactivate =>
      status == ItemStatus.retrieved || isExpired || rawStatus.toUpperCase() != 'ACTIVE';

  static String calculateRemaining(DateTime? expiresAt) {
    if (expiresAt == null) return '—';
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    if (difference.isNegative) {
      return 'Sesi habis';
    }
    if (difference.inHours >= 48) {
      final days = (difference.inHours / 24).floor();
      return '$days hari lagi';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} jam lagi';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} mnt lagi';
    } else {
      return '< 1 mnt lagi';
    }
  }

  static IconData resolveIcon(String category, String facility) {
    final c = category.toLowerCase();
    final f = facility.toLowerCase();
    if (c.contains('pakaian') ||
        c.contains('baju') ||
        c.contains('celana') ||
        c.contains('linen')) {
      return Icons.checkroom_rounded;
    }
    if (c.contains('makan') ||
        c.contains('bekal') ||
        c.contains('snack') ||
        c == 'instant') {
      return Icons.lunch_dining_rounded;
    }
    if (c.contains('segar') ||
        c.contains('sayur') ||
        c.contains('buah') ||
        c.contains('telur') ||
        c == 'raw') {
      return Icons.egg_alt_rounded;
    }
    if (c.contains('kain') || c.contains('handuk')) {
      return Icons.dry_cleaning_rounded;
    }
    if (f.contains('jemuran')) {
      return Icons.local_laundry_service_rounded;
    }
    return Icons.kitchen_rounded;
  }

  static Color resolveArtBg(String category, String facility) {
    final c = category.toLowerCase();
    if (c.contains('pakaian')) return const Color(0xFFF0E8D8);
    if (c.contains('segar') || c.contains('sayur') || c == 'raw') {
      return const Color(0xFFE7EDD9);
    }
    if (c.contains('kain') || c.contains('handuk')) {
      return const Color(0xFFE3EBEA);
    }
    if (c.contains('makan') || c == 'instant') {
      return const Color(0xFFF2E5D7);
    }
    return const Color(0xFFECEFE7);
  }

  static Color resolveArtColor(String category, String facility) {
    final c = category.toLowerCase();
    if (c.contains('pakaian')) return const Color(0xFF9A7450);
    if (c.contains('segar') || c.contains('sayur') || c == 'raw') {
      return const Color(0xFF62784C);
    }
    if (c.contains('kain') || c.contains('handuk')) {
      return const Color(0xFF668486);
    }
    if (c.contains('makan') || c == 'instant') {
      return const Color(0xFFAD7652);
    }
    return forest;
  }

  static String formatCategoryLabel(String cat) {
    if (cat.toUpperCase() == 'RAW') return 'Bahan Mentah';
    if (cat.toUpperCase() == 'INSTANT') return 'Makanan Instan & Matang';
    return cat;
  }

  factory KGItem.fromJson(Map<String, dynamic>? json, {int? currentUserId}) {
    if (json == null) {
      return KGItem(
        name: 'Barang',
        category: 'Lainnya',
        facility: 'Jemuran',
        room: '08',
        remaining: '—',
        icon: Icons.inventory_2_outlined,
        artBg: const Color(0xFFECEFE7),
        artColor: forest,
        status: ItemStatus.active,
      );
    }

    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '');
    final name = json['name']?.toString() ?? 'Barang';
    final category = json['category']?.toString() ?? 'Lainnya';
    final facility = json['facility']?.toString() ??
        (json['facility_type']?.toString() ?? 'Jemuran');

    String room = '08';
    if (json['room_number'] != null) {
      room = json['room_number'].toString();
    } else if (json['room'] != null) {
      if (json['room'] is Map) {
        room = json['room']['room_number']?.toString() ??
            json['room']['number']?.toString() ??
            '08';
      } else {
        room = json['room'].toString();
      }
    } else if (json['user'] is Map && json['user']['room_number'] != null) {
      room = json['user']['room_number'].toString();
    }

    final rawStatus = (json['status']?.toString() ??
            (json['usage_status']?.toString() ?? 'ACTIVE'))
        .toUpperCase();

    ItemStatus status;
    if (rawStatus == 'ACTIVE') {
      status = ItemStatus.active;
    } else if (rawStatus == 'EXPIRED') {
      status = ItemStatus.expired;
    } else {
      status = ItemStatus.retrieved;
    }

    DateTime? expiresAt;
    if (json['expires_at'] != null) {
      expiresAt = DateTime.tryParse(json['expires_at'].toString())?.toLocal();
    }

    DateTime? createdAt;
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'].toString())?.toLocal();
    }

    int? userId;
    if (json['user_id'] != null) {
      userId = json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id'].toString());
    } else if (json['user'] is Map && json['user']['id'] != null) {
      userId = json['user']['id'] is int
          ? json['user']['id'] as int
          : int.tryParse(json['user']['id'].toString());
    }

    final bool isMine = (currentUserId != null && userId != null)
        ? (userId == currentUserId)
        : (json['is_mine'] == true);

    final photoUrl = json['photo_url']?.toString() ?? json['photo']?.toString();

    final color = json['color']?.toString();
    final brand = json['brand']?.toString();
    final distinctiveMarks = json['distinctive_marks']?.toString();

    List<ItemActivity> activities = [];
    if (json['activities'] is List) {
      activities = (json['activities'] as List)
          .whereType<Map<String, dynamic>>()
          .map((a) => ItemActivity.fromJson(a,
              defaultItemName: name,
              defaultFacility: facility,
              defaultRoom: room))
          .toList();
    }

    return KGItem(
      id: id,
      name: name,
      category: category,
      facility: facility,
      room: room,
      remaining: calculateRemaining(expiresAt),
      icon: resolveIcon(category, facility),
      artBg: resolveArtBg(category, facility),
      artColor: resolveArtColor(category, facility),
      photoUrl: photoUrl,
      userId: userId,
      isMine: isMine,
      status: status,
      rawStatus: rawStatus,
      expiresAt: expiresAt,
      createdAt: createdAt,
      color: color,
      brand: brand,
      distinctiveMarks: distinctiveMarks,
      activities: activities,
    );
  }
}

class KGClaim {
  final int id;
  final int reportId;
  final int? claimantId;
  final String claimantName;
  final String claimantRoom;
  final String privateDetails;
  final String? evidenceUrl;
  final String status; // PENDING, APPROVED, REJECTED
  final String? resolutionNotes;
  final DateTime createdAt;

  const KGClaim({
    required this.id,
    required this.reportId,
    this.claimantId,
    required this.claimantName,
    required this.claimantRoom,
    required this.privateDetails,
    this.evidenceUrl,
    required this.status,
    this.resolutionNotes,
    required this.createdAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  factory KGClaim.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return KGClaim(
        id: 0,
        reportId: 0,
        claimantName: 'Penghuni',
        claimantRoom: '08',
        privateDetails: '',
        status: 'PENDING',
        createdAt: DateTime.now(),
      );
    }

    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;

    final reportId = json['incident_report_id'] is int
        ? json['incident_report_id'] as int
        : int.tryParse(json['incident_report_id']?.toString() ??
                (json['report_id']?.toString() ?? '')) ??
            0;

    final claimantId = json['user_id'] is int
        ? json['user_id'] as int
        : int.tryParse(json['user_id']?.toString() ?? '');

    final claimantName = json['claimant_name']?.toString() ??
        (json['claimant'] is Map
            ? json['claimant']['name']?.toString()
            : null) ??
        (json['user'] is Map ? json['user']['name']?.toString() : null) ??
        'Penghuni';

    final claimantRoom = json['claimant_room']?.toString() ??
        (json['claimant'] is Map
            ? json['claimant']['room_number']?.toString()
            : null) ??
        (json['user'] is Map
            ? json['user']['room_number']?.toString()
            : null) ??
        '—';

    final privateDetails = json['private_details']?.toString() ??
        (json['details']?.toString() ?? '');

    final evidenceUrl =
        json['evidence_url']?.toString() ?? json['evidence']?.toString();

    final status = (json['status']?.toString() ?? 'PENDING').toUpperCase();
    final resolutionNotes = json['resolution_notes']?.toString();

    DateTime createdAt = DateTime.now();
    if (json['created_at'] != null) {
      createdAt =
          DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              createdAt;
    }

    return KGClaim(
      id: id,
      reportId: reportId,
      claimantId: claimantId,
      claimantName: claimantName,
      claimantRoom: claimantRoom,
      privateDetails: privateDetails,
      evidenceUrl: evidenceUrl,
      status: status,
      resolutionNotes: resolutionNotes,
      createdAt: createdAt,
    );
  }
}

class KGReport {
  final int id;
  final int? kgItemId;
  final String? itemName;
  final String kind; // MISSING, SWAPPED, FOUND
  final String notes;
  final String status; // OPEN, UNDER_REVIEW, RESOLVED
  final String reporterName;
  final String roomNumber;
  final String? evidenceUrl;
  final String? handlingNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final List<KGClaim> claims;

  const KGReport({
    required this.id,
    this.kgItemId,
    this.itemName,
    required this.kind,
    required this.notes,
    required this.status,
    required this.reporterName,
    required this.roomNumber,
    this.evidenceUrl,
    this.handlingNotes,
    required this.createdAt,
    this.resolvedAt,
    this.claims = const [],
  });

  bool get isOpen => status.toUpperCase() == 'OPEN';
  bool get isUnderReview => status.toUpperCase() == 'UNDER_REVIEW';
  bool get isResolved => status.toUpperCase() == 'RESOLVED';

  String get kindLabel {
    switch (kind.toUpperCase()) {
      case 'MISSING':
        return 'Hilang';
      case 'SWAPPED':
        return 'Tertukar';
      case 'FOUND':
        return 'Barang Temuan';
      default:
        return kind;
    }
  }

  factory KGReport.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return KGReport(
        id: 0,
        kind: 'MISSING',
        notes: '',
        status: 'OPEN',
        reporterName: 'Penghuni',
        roomNumber: '08',
        createdAt: DateTime.now(),
      );
    }

    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;

    final kgItemId = json['item_id'] is int
        ? json['item_id'] as int
        : int.tryParse(json['item_id']?.toString() ??
            (json['kg_item_id']?.toString() ?? ''));

    final itemName = json['item_name']?.toString() ??
        (json['item'] is Map ? json['item']['name']?.toString() : null);

    final rawKind =
        json['kind']?.toString() ?? (json['type']?.toString() ?? 'MISSING');
    final kind = rawKind.toUpperCase();

    final notes = json['notes']?.toString() ??
        (json['details']?.toString() ??
            (json['description']?.toString() ?? ''));

    final status = (json['status']?.toString() ?? 'OPEN').toUpperCase();

    final reporterName = json['reporter_name']?.toString() ??
        (json['user'] is Map ? json['user']['name']?.toString() : null) ??
        'Penghuni';

    final roomNumber = json['room_number']?.toString() ??
        (json['user'] is Map
            ? json['user']['room_number']?.toString()
            : null) ??
        '08';

    final evidenceUrl =
        json['evidence_url']?.toString() ?? json['evidence']?.toString();

    final handlingNotes = json['handling_notes']?.toString() ??
        json['resolution_notes']?.toString();

    DateTime createdAt = DateTime.now();
    if (json['created_at'] != null) {
      createdAt =
          DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              createdAt;
    }

    DateTime? resolvedAt;
    if (json['resolved_at'] != null) {
      resolvedAt =
          DateTime.tryParse(json['resolved_at'].toString())?.toLocal();
    }

    List<KGClaim> claims = [];
    if (json['claims'] is List) {
      claims = (json['claims'] as List)
          .whereType<Map<String, dynamic>>()
          .map((c) => KGClaim.fromJson(c))
          .toList();
    }

    return KGReport(
      id: id,
      kgItemId: kgItemId,
      itemName: itemName,
      kind: kind,
      notes: notes,
      status: status,
      reporterName: reporterName,
      roomNumber: roomNumber,
      evidenceUrl: evidenceUrl,
      handlingNotes: handlingNotes,
      createdAt: createdAt,
      resolvedAt: resolvedAt,
      claims: claims,
    );
  }
}

class KGNotification {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String? type;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  const KGNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.type,
    this.data,
    required this.createdAt,
  });

  factory KGNotification.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return KGNotification(
        id: '0',
        title: 'Notifikasi',
        body: '',
        isRead: true,
        createdAt: DateTime.now(),
      );
    }

    final id = json['id']?.toString() ?? '0';
    final title = json['title']?.toString() ??
        (json['data'] is Map ? json['data']['title']?.toString() : null) ??
        'Pemberitahuan';
    final body = json['body']?.toString() ??
        (json['message']?.toString()) ??
        (json['data'] is Map ? json['data']['message']?.toString() : null) ??
        '';

    final isRead = json['read_at'] != null ||
        json['is_read'] == true ||
        json['is_read'] == 1;

    final type = json['type']?.toString();
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : null;

    DateTime createdAt = DateTime.now();
    if (json['created_at'] != null) {
      createdAt =
          DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              createdAt;
    }

    return KGNotification(
      id: id,
      title: title,
      body: body,
      isRead: isRead,
      type: type,
      data: data,
      createdAt: createdAt,
    );
  }
}

class DashboardSummary {
  final int activeItemsCount;
  final int expiredCount;
  final int openIncidentsCount;
  final int pendingClaimsCount;

  const DashboardSummary({
    this.activeItemsCount = 0,
    this.expiredCount = 0,
    this.openIncidentsCount = 0,
    this.pendingClaimsCount = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DashboardSummary();

    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final activeItems = parseCount(json['active_items_count'] ??
        json['active_items'] ??
        json['active_count']);
    final expired = parseCount(json['expired_sessions_count'] ??
        json['expired_items'] ??
        json['expired_count']);
    final openIncidents = parseCount(json['open_incidents_count'] ??
        json['open_reports'] ??
        json['incidents_count']);
    final pendingClaims = parseCount(json['pending_claims_count'] ??
        json['pending_claims'] ??
        json['claims_count']);

    return DashboardSummary(
      activeItemsCount: activeItems,
      expiredCount: expired,
      openIncidentsCount: openIncidents,
      pendingClaimsCount: pendingClaims,
    );
  }
}
