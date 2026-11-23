import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic errors;

  ApiException(this.message, {this.statusCode = 400, this.errors});

  @override
  String toString() => message;
}

class ApiService {
  // Untuk build APK ke HP fisik: isi dengan IP lokal PC/laptop, misalnya 'http://192.168.1.10:8000/api'
  static String customDeviceUrl =
      'https://establish-flagship-banish.ngrok-free.dev/api';

  // Penentuan baseUrl otomatis lintas platform (Web, Android Emulator, Desktop/iOS/Fisik)
  static String get baseUrl {
    if (customDeviceUrl.trim().isNotEmpty) {
      return customDeviceUrl.trim();
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api';
  }

  static const String _keyToken = 'kg_auth_token';
  static const String _keyUser = 'kg_auth_user';

  // ===================== MODE OFFLINE / DUMMY DATA (JURI) =====================
  static bool _isOfflineMode = false;
  static bool get isOfflineMode => _isOfflineMode;

  static Future<bool> _checkOffline() async {
    if (_isOfflineMode) return true;
    final token = await getToken();
    if (token != null && token.startsWith('dummy_offline_token_')) {
      _isOfflineMode = true;
      return true;
    }
    return false;
  }

  static const Map<String, dynamic> _dummyResidentUser = {
    'id': 99,
    'name': 'Juri Demo (Penghuni)',
    'email': 'juri@kosguard.test',
    'role': 'resident',
    'room_number': 'A-04',
    'email_verified_at': '2026-11-23T08:00:00.000000Z',
    'created_at': '2026-11-23T08:00:00.000000Z',
    'updated_at': '2026-11-23T08:00:00.000000Z',
  };

  static const Map<String, dynamic> _dummyOwnerUser = {
    'id': 100,
    'name': 'Pemilik Kos (Demo Offline)',
    'email': 'owner.juri@kosguard.test',
    'role': 'owner',
    'room_number': null,
    'email_verified_at': '2026-11-23T08:00:00.000000Z',
    'created_at': '2026-11-23T08:00:00.000000Z',
    'updated_at': '2026-11-23T08:00:00.000000Z',
  };

  static final List<Map<String, dynamic>> _dummyItems = [
    {
      'id': 101,
      'user_id': 99,
      'name': 'Sayur & Buah Segar',
      'category': 'Bahan Mentah',
      'facility': 'Kulkas',
      'status': 'ACTIVE',
      'color': 'Beragam',
      'brand': null,
      'distinctive_marks': 'Wadah bening berlabel Kamar A-04',
      'photo_url': null,
      'photo_path': null,
      'duration_hours': 168,
      'expires_at': '2027-11-23T08:00:00.000000Z',
      'created_at': '2026-11-23T07:30:00.000000Z',
      'user': _dummyResidentUser,
    },
    {
      'id': 102,
      'user_id': 99,
      'name': 'Jaket Hoodie Hitam',
      'category': 'Pakaian',
      'facility': 'Jemuran',
      'status': 'ACTIVE',
      'color': 'Hitam',
      'brand': 'Uniqlo',
      'distinctive_marks': 'Gantungan baju warna merah',
      'photo_url': null,
      'photo_path': null,
      'duration_hours': 12,
      'expires_at': '2027-11-23T20:00:00.000000Z',
      'created_at': '2026-11-23T08:00:00.000000Z',
      'user': _dummyResidentUser,
    },
    {
      'id': 103,
      'user_id': 98,
      'name': 'Kotak Makan Tupperware',
      'category': 'Makanan Matang',
      'facility': 'Kulkas',
      'status': 'ACTIVE',
      'color': 'Hijau Tosca',
      'brand': 'Tupperware',
      'distinctive_marks': 'Rak tengah kulkas',
      'photo_url': null,
      'photo_path': null,
      'duration_hours': 48,
      'expires_at': '2027-11-25T08:00:00.000000Z',
      'created_at': '2026-11-23T06:15:00.000000Z',
      'user': {
        'id': 98,
        'name': 'Budi Santoso',
        'email': 'budi@kosguard.test',
        'role': 'resident',
        'room_number': 'B-02',
      },
    },
  ];

  static final List<Map<String, dynamic>> _dummyReports = [
    {
      'id': 201,
      'item_id': 102,
      'reporter_id': 99,
      'kind': 'MISSING',
      'status': 'OPEN',
      'notes': 'Jaket hoodie hitam belum ditemukan di area Jemuran.',
      'handling_notes': null,
      'evidence_url': null,
      'evidence_path': null,
      'created_at': '2026-11-23T09:00:00.000000Z',
      'reporter': _dummyResidentUser,
    },
    {
      'id': 202,
      'item_id': 101,
      'reporter_id': 98,
      'kind': 'FOUND',
      'status': 'INVESTIGATING',
      'notes':
          'Sayur dan buah segar milik Kamar A-04 ditemukan kembali di Kulkas.',
      'handling_notes': 'Diamankan di Kulkas untuk verifikasi pemilik.',
      'evidence_url': null,
      'evidence_path': null,
      'created_at': '2026-11-23T08:15:00.000000Z',
      'reporter': {
        'id': 98,
        'name': 'Budi Santoso',
        'email': 'budi@kosguard.test',
        'role': 'resident',
        'room_number': 'B-02',
      },
    },
  ];

  static final List<Map<String, dynamic>> _dummyClaims = [
    {
      'id': 301,
      'report_id': 202,
      'claimant_id': 99,
      'claimant_room': 'A-04',
      'private_details':
          'Wadah transparan berisi sayur dan buah segar berlabel "A-04".',
      'status': 'PENDING',
      'resolution_notes': null,
      'created_at': '2026-11-23T09:30:00.000000Z',
      'claimant': {
        'id': 99,
        'name': 'Penghuni',
        'room_number': 'A-04',
      },
      'report': _dummyReports[1],
    },
  ];

  static Map<String, dynamic> _dummyRoomQr = {
    'id': 4,
    'room_number': 'A-04',
    'qr_token': 'KG-ROOM-A04-OFFLINE2026',
    'resident_name': 'Juri Demo (Penghuni)',
    'status': 'ACTIVE',
  };

  static final List<Map<String, dynamic>> _dummyNotifications = [
    {
      'id': 401,
      'title': 'Mode Offline Aktif',
      'body':
          'Anda sedang menggunakan akun demo offline untuk pengujian juri tanpa koneksi server.',
      'type': 'SYSTEM',
      'read_at': null,
      'created_at': '2026-11-23T08:00:00.000000Z',
    },
    {
      'id': 402,
      'title': 'Barang Terdaftar di Kulkas',
      'body': 'Sayur & Buah Segar milik Kamar A-04 aktif dipantau.',
      'type': 'ITEM',
      'read_at': null,
      'created_at': '2026-11-23T07:30:00.000000Z',
    },
  ];

  // Helper untuk menormalisasi URL foto backend agar mengarah ke host server aktif
  static String? resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();
    final currentBase = baseUrl;
    final baseUri = Uri.parse(currentBase);

    // Jika URL relatif (contoh: "/storage/photos/abc.jpg" atau "storage/photos/abc.jpg")
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      final portSuffix = baseUri.hasPort ? ':${baseUri.port}' : '';
      return '${baseUri.scheme}://${baseUri.host}$portSuffix$cleanPath';
    }

    try {
      final uri = Uri.parse(trimmed);
      // Ganti localhost atau 127.0.0.1 dengan host server yang sedang aktif
      if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
        return uri
            .replace(
              scheme: baseUri.scheme,
              host: baseUri.host,
              port: baseUri.hasPort
                  ? baseUri.port
                  : (uri.hasPort ? uri.port : null),
            )
            .toString();
      }
      return trimmed;
    } catch (_) {
      return trimmed;
    }
  }

  // Kompatibilitas mundur
  static String? normalizePhotoUrl(String? url) => resolveImageUrl(url);

  // Pengelolaan Token & Cache User
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
  }

  // Headers standar request
  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (withAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Penanganan response HTTP dari Laravel
  static dynamic _handleResponse(http.Response response) async {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        if (body.containsKey('data')) {
          return body['data'];
        }
        return body;
      }
      return body;
    }

    // Tangani 401 Unauthorized
    if (response.statusCode == 401) {
      await clearToken();
      await clearUser();
      String msg = 'Sesi telah berakhir. Silakan login kembali.';
      if (body is Map && body['message'] != null) {
        msg = body['message'].toString();
      }
      throw ApiException(msg, statusCode: 401);
    }

    // Tangani 422 Validation Error dari Laravel
    if (response.statusCode == 422 && body is Map<String, dynamic>) {
      final errors = body['errors'];
      if (errors is Map) {
        final messages = <String>[];
        for (final val in errors.values) {
          if (val is List) {
            messages.addAll(val.map((e) => e?.toString() ?? ''));
          } else if (val != null) {
            messages.add(val.toString());
          }
        }
        if (messages.isNotEmpty) {
          throw ApiException(messages.join('\n'),
              statusCode: 422, errors: errors);
        }
      }
    }

    // Error umum lainnya
    String errorMessage = 'Terjadi kesalahan (${response.statusCode})';
    if (body is Map && body['message'] != null) {
      errorMessage = body['message'].toString();
    } else if (response.reasonPhrase != null &&
        response.reasonPhrase!.isNotEmpty) {
      errorMessage = response.reasonPhrase!;
    }

    throw ApiException(errorMessage,
        statusCode: response.statusCode, errors: body);
  }

  // ===================== AUTH METHODS =====================

  /// POST /login
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Jalur Offline Otomatis untuk Akun Demo Juri
    if (normalizedEmail == 'juri@kosguard.test' ||
        normalizedEmail == 'owner.juri@kosguard.test') {
      _isOfflineMode = true;
      final isOwner = normalizedEmail == 'owner.juri@kosguard.test';
      final dummyUser = isOwner ? _dummyOwnerUser : _dummyResidentUser;
      final dummyToken = isOwner
          ? 'dummy_offline_token_owner_2026'
          : 'dummy_offline_token_resident_2026';

      await saveToken(dummyToken);
      await saveUser(dummyUser);

      return {
        'success': true,
        'token': dummyToken,
        'user': dummyUser,
        'message': 'Login berhasil (Mode Offline)',
      };
    }

    _isOfflineMode = false;
    final uri = Uri.parse('$baseUrl/login');
    final response = await http.post(
      uri,
      headers: await _headers(withAuth: false),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    final data = await _handleResponse(response);
    Map<String, dynamic> resultMap = {};
    if (data is Map<String, dynamic>) {
      resultMap = data;
    }

    String? token;
    if (resultMap['token'] != null) {
      token = resultMap['token'].toString();
    } else if (resultMap['access_token'] != null) {
      token = resultMap['access_token'].toString();
    }

    if (token != null) {
      await saveToken(token);
    }

    if (resultMap['user'] is Map<String, dynamic>) {
      await saveUser(resultMap['user'] as Map<String, dynamic>);
    } else {
      try {
        await getMe();
      } catch (_) {}
    }

    return resultMap;
  }

  /// POST /register
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String roomNumber,
  ) async {
    _isOfflineMode = false;
    final uri = Uri.parse('$baseUrl/register');
    final response = await http.post(
      uri,
      headers: await _headers(withAuth: false),
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': password,
        'room_number': roomNumber.trim(),
      }),
    );

    final data = await _handleResponse(response);
    Map<String, dynamic> resultMap = {};
    if (data is Map<String, dynamic>) {
      resultMap = data;
    }

    String? token;
    if (resultMap['token'] != null) {
      token = resultMap['token'].toString();
    } else if (resultMap['access_token'] != null) {
      token = resultMap['access_token'].toString();
    }

    if (token != null) {
      await saveToken(token);
    }

    if (resultMap['user'] is Map<String, dynamic>) {
      await saveUser(resultMap['user'] as Map<String, dynamic>);
    }

    return resultMap;
  }

  /// GET /me
  static Future<Map<String, dynamic>> getMe() async {
    if (await _checkOffline()) {
      final cached = await getUser();
      return cached ?? _dummyResidentUser;
    }

    final uri = Uri.parse('$baseUrl/me');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);

    if (data is Map<String, dynamic>) {
      await saveUser(data);
      return data;
    }
    return {};
  }

  /// POST /logout
  static Future<void> logout() async {
    final offline = await _checkOffline();
    try {
      if (!offline) {
        final uri = Uri.parse('$baseUrl/logout');
        await http.post(uri, headers: await _headers());
      }
    } catch (_) {
    } finally {
      _isOfflineMode = false;
      await clearToken();
      await clearUser();
    }
  }

  // ===================== ITEMS METHODS =====================

  /// GET /items
  static Future<List<dynamic>> getItems({
    String? facility,
    String? status,
    bool mine = false,
  }) async {
    if (await _checkOffline()) {
      return _dummyItems.where((item) {
        if (facility != null && facility.isNotEmpty && facility != 'Semua') {
          if (item['facility'] != facility) return false;
        }
        if (status != null && status.isNotEmpty) {
          if (item['status'] != status) return false;
        }
        if (mine) {
          if (item['user_id'] != 99) return false;
        }
        return true;
      }).toList();
    }

    final queryParams = <String, String>{};
    if (facility != null && facility.isNotEmpty && facility != 'Semua') {
      queryParams['facility'] = facility;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (mine) {
      queryParams['mine'] = '1';
    }

    Uri uri = Uri.parse('$baseUrl/items');
    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);

    if (data is List) {
      return data;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List;
    }
    return [];
  }

  /// POST /items (Menggunakan Uint8List bytes untuk foto agar kompatibel di Chrome & Android)
  static Future<Map<String, dynamic>> createItem({
    required String name,
    required String category,
    required String facility,
    required int durationHours,
    Uint8List? photoBytes,
    String? photoFileName,
    String? color,
    String? brand,
    String? distinctiveMarks,
  }) async {
    if (await _checkOffline()) {
      final now = DateTime.now();
      final newItem = <String, dynamic>{
        'id': 100 + _dummyItems.length + 1,
        'user_id': 99,
        'name': name.trim(),
        'category': category.trim(),
        'facility': facility.trim(),
        'status': 'ACTIVE',
        'color': color?.trim() ?? '',
        'brand': brand?.trim() ?? '',
        'distinctive_marks': distinctiveMarks?.trim() ?? '',
        'photo_url': null,
        'photo_path': null,
        'duration_hours': durationHours,
        'expires_at': now.add(Duration(hours: durationHours)).toIso8601String(),
        'created_at': now.toIso8601String(),
        'user': _dummyResidentUser,
      };
      _dummyItems.insert(0, newItem);
      return newItem;
    }

    final uri = Uri.parse('$baseUrl/items');
    final request = http.MultipartRequest('POST', uri);

    final token = await getToken();
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['name'] = name.trim();
    request.fields['category'] = category.trim();
    request.fields['facility'] = facility.trim();
    request.fields['duration_hours'] = durationHours.toString();

    if (color != null && color.trim().isNotEmpty) {
      request.fields['color'] = color.trim();
    }
    if (brand != null && brand.trim().isNotEmpty) {
      request.fields['brand'] = brand.trim();
    }
    if (distinctiveMarks != null && distinctiveMarks.trim().isNotEmpty) {
      request.fields['distinctive_marks'] = distinctiveMarks.trim();
    }

    if (photoBytes != null && photoBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: photoFileName ?? 'item_photo.jpg',
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = await _handleResponse(response);

    if (data is Map<String, dynamic>) {
      return data;
    }
    return {'success': true};
  }

  /// PUT /items/{id} - Update detail barang
  static Future<Map<String, dynamic>> updateItem(
    int id, {
    String? name,
    String? category,
    String? facility,
    String? color,
    String? brand,
    String? distinctiveMarks,
  }) async {
    if (await _checkOffline()) {
      final index = _dummyItems.indexWhere((e) => e['id'] == id);
      if (index != -1) {
        if (name != null) _dummyItems[index]['name'] = name.trim();
        if (category != null) _dummyItems[index]['category'] = category.trim();
        if (facility != null) _dummyItems[index]['facility'] = facility.trim();
        if (color != null) _dummyItems[index]['color'] = color.trim();
        if (brand != null) _dummyItems[index]['brand'] = brand.trim();
        if (distinctiveMarks != null) {
          _dummyItems[index]['distinctive_marks'] = distinctiveMarks.trim();
        }
        return _dummyItems[index];
      }
      return {'success': true};
    }

    final uri = Uri.parse('$baseUrl/items/$id');
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (category != null) payload['category'] = category.trim();
    if (facility != null) payload['facility'] = facility.trim();
    if (color != null) payload['color'] = color.trim();
    if (brand != null) payload['brand'] = brand.trim();
    if (distinctiveMarks != null) {
      payload['distinctive_marks'] = distinctiveMarks.trim();
    }

    final response = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {'success': true};
  }

  /// POST /items/{id}/reactivate - Aktifkan kembali sesi fasilitas barang
  static Future<Map<String, dynamic>> reactivateItem(
    int id, {
    required String facility,
    required int durationHours,
    String? category,
  }) async {
    if (await _checkOffline()) {
      final index = _dummyItems.indexWhere((e) => e['id'] == id);
      if (index != -1) {
        _dummyItems[index]['status'] = 'ACTIVE';
        _dummyItems[index]['facility'] = facility.trim();
        _dummyItems[index]['duration_hours'] = durationHours;
        _dummyItems[index]['expires_at'] = DateTime.now()
            .add(Duration(hours: durationHours))
            .toIso8601String();
        if (category != null && category.isNotEmpty) {
          _dummyItems[index]['category'] = category.trim();
        }
        return _dummyItems[index];
      }
      return {'success': true};
    }

    final uri = Uri.parse('$baseUrl/items/$id/reactivate');
    final payload = <String, dynamic>{
      'facility': facility.trim(),
      'duration_hours': durationHours,
    };
    if (category != null && category.isNotEmpty) {
      payload['category'] = category.trim();
    }

    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {'success': true};
  }

  /// GET /items/{id}
  static Future<Map<String, dynamic>> getItemDetail(int id) async {
    if (await _checkOffline()) {
      return _dummyItems.firstWhere(
        (e) => e['id'] == id,
        orElse: () => _dummyItems.first,
      );
    }

    final uri = Uri.parse('$baseUrl/items/$id');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);

    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  /// POST /items/{id}/retrieve
  static Future<Map<String, dynamic>> retrieveItem(int id) async {
    if (await _checkOffline()) {
      final index = _dummyItems.indexWhere((e) => e['id'] == id);
      if (index != -1) {
        _dummyItems[index]['status'] = 'RETRIEVED';
        return _dummyItems[index];
      }
      return {'success': true};
    }

    final uri = Uri.parse('$baseUrl/items/$id/retrieve');
    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({}),
    );
    final data = await _handleResponse(response);

    if (data is Map<String, dynamic>) {
      return data;
    }
    return {'success': true};
  }

  // ===================== REPORTS & INCIDENTS =====================

  /// GET /reports
  static Future<List<dynamic>> getReports() async {
    if (await _checkOffline()) {
      return _dummyReports;
    }

    final uri = Uri.parse('$baseUrl/reports');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);

    if (data is List) {
      return data;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List;
    }
    return [];
  }

  /// POST /reports (Mendukung upload bukti foto/evidence via bytes)
  static Future<Map<String, dynamic>> createReport({
    int? kgItemId,
    required String kind,
    required String notes,
    Uint8List? evidenceBytes,
    String? evidenceFileName,
  }) async {
    if (await _checkOffline()) {
      final newReport = <String, dynamic>{
        'id': 200 + _dummyReports.length + 1,
        'item_id': kgItemId,
        'reporter_id': 99,
        'kind': kind,
        'status': 'OPEN',
        'notes': notes.trim(),
        'handling_notes': null,
        'evidence_url': null,
        'evidence_path': null,
        'created_at': DateTime.now().toIso8601String(),
        'reporter': _dummyResidentUser,
      };
      _dummyReports.insert(0, newReport);
      return newReport;
    }

    final uri = Uri.parse('$baseUrl/reports');

    if (evidenceBytes != null && evidenceBytes.isNotEmpty) {
      final request = http.MultipartRequest('POST', uri);
      final token = await getToken();
      request.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['kind'] = kind;
      request.fields['notes'] = notes.trim();
      if (kgItemId != null) {
        request.fields['item_id'] = kgItemId.toString();
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'evidence',
          evidenceBytes,
          filename: evidenceFileName ?? 'evidence.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = await _handleResponse(response);
      if (data is Map<String, dynamic>) return data;
      return {'success': true};
    }

    final payload = <String, dynamic>{
      'kind': kind,
      'notes': notes.trim(),
    };
    if (kgItemId != null) {
      payload['item_id'] = kgItemId;
    }

    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    final data = await _handleResponse(response);

    if (data is Map<String, dynamic>) {
      return data;
    }
    return {'success': true};
  }

  /// POST /reports/{id}/status - Pemilik kos memperbarui status penanganan insiden
  static Future<Map<String, dynamic>> updateReportStatus(
    int reportId, {
    required String status,
    String? notes,
  }) async {
    if (await _checkOffline()) {
      final index = _dummyReports.indexWhere((e) => e['id'] == reportId);
      if (index != -1) {
        _dummyReports[index]['status'] = status.toUpperCase();
        if (notes != null && notes.trim().isNotEmpty) {
          _dummyReports[index]['handling_notes'] = notes.trim();
        }
        return _dummyReports[index];
      }
      return {'success': true};
    }

    final uri = Uri.parse('$baseUrl/reports/$reportId/status');
    final payload = <String, dynamic>{
      'status': status.toUpperCase(),
    };
    if (notes != null && notes.trim().isNotEmpty) {
      payload['handling_notes'] = notes.trim();
    }

    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {'success': true};
  }

  /// POST /reports/{id}/resolve
  static Future<Map<String, dynamic>> resolveReport(int id) async {
    return updateReportStatus(id, status: 'RESOLVED');
  }

  // ===================== CLAIMS =====================

  /// POST /reports/{id}/claims - Penghuni mengajukan klaim kepemilikan privat
  static Future<Map<String, dynamic>> submitClaim(
    int reportId, {
    required String privateDetails,
    Uint8List? evidenceBytes,
    String? evidenceFileName,
  }) async {
    if (await _checkOffline()) {
      final targetReport = _dummyReports.firstWhere(
        (e) => e['id'] == reportId,
        orElse: () => _dummyReports.first,
      );
      final newClaim = <String, dynamic>{
        'id': 300 + _dummyClaims.length + 1,
        'report_id': reportId,
        'claimant_id': 99,
        'private_details': privateDetails.trim(),
        'status': 'PENDING',
        'resolution_notes': null,
        'created_at': DateTime.now().toIso8601String(),
        'claimant': _dummyResidentUser,
        'report': targetReport,
      };
      _dummyClaims.insert(0, newClaim);
      return newClaim;
    }

    final uri = Uri.parse('$baseUrl/reports/$reportId/claims');

    if (evidenceBytes != null && evidenceBytes.isNotEmpty) {
      final request = http.MultipartRequest('POST', uri);
      final token = await getToken();
      request.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['private_details'] = privateDetails.trim();
      request.files.add(
        http.MultipartFile.fromBytes(
          'evidence',
          evidenceBytes,
          filename: evidenceFileName ?? 'claim_evidence.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = await _handleResponse(response);
      if (data is Map<String, dynamic>) return data;
      return {'success': true};
    }

    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'private_details': privateDetails.trim()}),
    );
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {'success': true};
  }

  /// GET /claims - Pemilik kos melihat semua klaim masuk
  static Future<List<dynamic>> getClaims() async {
    if (await _checkOffline()) {
      return _dummyClaims;
    }

    final uri = Uri.parse('$baseUrl/claims');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);

    if (data is List) {
      return data;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List;
    }
    return [];
  }

  /// POST /claims/{id}/review - Pemilik kos memverifikasi (APPROVED / REJECTED)
  static Future<Map<String, dynamic>> reviewClaim(
    int claimId, {
    required String action,
    String? resolutionNotes,
  }) async {
    if (await _checkOffline()) {
      final index = _dummyClaims.indexWhere((e) => e['id'] == claimId);
      if (index != -1) {
        _dummyClaims[index]['status'] = action.toUpperCase();
        if (resolutionNotes != null && resolutionNotes.trim().isNotEmpty) {
          _dummyClaims[index]['resolution_notes'] = resolutionNotes.trim();
        }
        return _dummyClaims[index];
      }
      return {'success': true};
    }

    final uri = Uri.parse('$baseUrl/claims/$claimId/review');
    final payload = <String, dynamic>{
      'action': action.toUpperCase(),
    };
    if (resolutionNotes != null && resolutionNotes.trim().isNotEmpty) {
      payload['resolution_notes'] = resolutionNotes.trim();
    }

    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {'success': true};
  }

  // ===================== ROOM QR =====================

  /// GET /rooms/my-qr - Mengambil identitas kamar dan token QR kamar
  static Future<Map<String, dynamic>> getMyRoomQr() async {
    if (await _checkOffline()) {
      return _dummyRoomQr;
    }

    final uri = Uri.parse('$baseUrl/rooms/my-qr');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// POST /rooms/{id}/regenerate-qr - Memperbarui token QR kamar
  static Future<Map<String, dynamic>> regenerateRoomQr(int roomId) async {
    if (await _checkOffline()) {
      _dummyRoomQr = {
        ..._dummyRoomQr,
        'qr_token': 'KG-ROOM-A04-${DateTime.now().millisecondsSinceEpoch}',
      };
      return _dummyRoomQr;
    }

    Uri uri = Uri.parse('$baseUrl/rooms/$roomId/regenerate-qr');
    http.Response response;
    try {
      response =
          await http.post(uri, headers: await _headers(), body: jsonEncode({}));
    } catch (_) {
      uri = Uri.parse('$baseUrl/rooms/my-qr/regenerate');
      response =
          await http.post(uri, headers: await _headers(), body: jsonEncode({}));
    }
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// GET /rooms/scan/{token} - Membuka inventaris kamar tanpa membocorkan kontak privat
  static Future<Map<String, dynamic>> scanRoomQr(String token) async {
    if (await _checkOffline()) {
      return {
        'room_number': 'A-04',
        'status': 'ACTIVE',
        'qr_token': token.trim(),
        'items': _dummyItems.where((e) => e['user_id'] == 99).toList(),
      };
    }

    final cleanToken = Uri.encodeComponent(token.trim());
    final uri = Uri.parse('$baseUrl/rooms/scan/$cleanToken');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  // ===================== NOTIFICATIONS =====================

  /// GET /notifications
  static Future<List<dynamic>> getNotifications() async {
    if (await _checkOffline()) {
      return _dummyNotifications;
    }

    final uri = Uri.parse('$baseUrl/notifications');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);

    if (data is List) {
      return data;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List;
    }
    return [];
  }

  /// POST /notifications/read-all
  static Future<void> markAllNotificationsRead() async {
    if (await _checkOffline()) {
      final now = DateTime.now().toIso8601String();
      for (final notif in _dummyNotifications) {
        notif['read_at'] = now;
      }
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/notifications/read-all');
      await http.post(uri, headers: await _headers(), body: jsonEncode({}));
    } catch (_) {}
  }

  // ===================== OWNER DASHBOARD =====================

  /// GET /dashboard/summary
  static Future<Map<String, dynamic>> getDashboardSummary() async {
    if (await _checkOffline()) {
      final activeItems =
          _dummyItems.where((e) => e['status'] == 'ACTIVE').length;
      final openReports =
          _dummyReports.where((e) => e['status'] != 'RESOLVED').length;
      final pendingClaims =
          _dummyClaims.where((e) => e['status'] == 'PENDING').length;

      return {
        'total_rooms': 12,
        'occupied_rooms': 7,
        'total_residents': 7,
        'active_items': activeItems,
        'total_items_active': activeItems,
        'open_reports': openReports,
        'total_reports_pending': openReports,
        'pending_claims': pendingClaims,
        'recent_activities': [],
      };
    }

    final uri = Uri.parse('$baseUrl/dashboard/summary');
    final response = await http.get(uri, headers: await _headers());
    final data = await _handleResponse(response);
    if (data is Map<String, dynamic>) return data;
    return {};
  }
}
