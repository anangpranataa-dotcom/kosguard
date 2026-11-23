import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class RoomQrScreen extends StatefulWidget {
  final KGUser currentUser;

  const RoomQrScreen({super.key, required this.currentUser});

  @override
  State<RoomQrScreen> createState() => _RoomQrScreenState();
}

class _RoomQrScreenState extends State<RoomQrScreen> {
  bool _isLoading = true;

  String? _qrToken;
  int? _roomId;
  String? _roomNumber;
  String? _propertyName;
  List<dynamic> _roomMembers = [];

  // Simulasi cek token QR kamar
  final _scanTokenController = TextEditingController();
  bool _isScanning = false;
  Map<String, dynamic>? _scanResult;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _fetchRoomQr();
  }

  @override
  void dispose() {
    _scanTokenController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoomQr() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getMyRoomQr();
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;

      setState(() {
        _qrToken = data['qr_token']?.toString() ??
            data['token']?.toString() ??
            'KG-RM-${widget.currentUser.roomNumber}-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
        _roomId = data['room_id'] is int
            ? data['room_id'] as int
            : int.tryParse(data['room_id']?.toString() ??
                (data['id']?.toString() ?? (widget.currentUser.roomId?.toString() ?? '1')));
        _roomNumber = data['room_number']?.toString() ?? widget.currentUser.roomNumber;
        _propertyName = data['property_name']?.toString() ?? widget.currentUser.propertyName;
        if (data['members'] is List) {
          _roomMembers = data['members'] as List;
        }
      });
    } catch (_) {
      setState(() {
        // Fallback default jika endpoint my-qr belum di-seed
        _qrToken ??= 'KG-RM-${widget.currentUser.roomNumber}-SECURE';
        _roomNumber ??= widget.currentUser.roomNumber;
        _propertyName ??= widget.currentUser.propertyName;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _regenerateToken() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Perbarui Token QR?',
            style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
        content: const Text(
          'Token QR sebelumnya akan langsung dinonaktifkan. Siapa pun yang memiliki token lama tidak lagi dapat mengakses inventaris kamar.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: forest),
            child: const Text('Perbarui'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.regenerateRoomQr(_roomId ?? 1);
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      final newToken = data['qr_token']?.toString() ?? data['token']?.toString();

      if (mounted) {
        setState(() {
          if (newToken != null && newToken.isNotEmpty) {
            _qrToken = newToken;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token QR kamar berhasil diperbarui.'),
            backgroundColor: forest,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _simulateScan() async {
    final token = _scanTokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _scanError = 'Masukkan token QR terlebih dahulu.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isScanning = true;
      _scanError = null;
      _scanResult = null;
    });

    try {
      final res = await ApiService.scanRoomQr(token);
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;

      if (mounted) {
        setState(() {
          _scanResult = data;
          _scanError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanError = e.toString().replaceAll('Exception: ', '');
          _scanResult = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'QR Kamar',
          style: TextStyle(
            color: ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading && _qrToken == null
            ? const Center(child: CircularProgressIndicator(color: forest, strokeWidth: 2))
            : RefreshIndicator(
                color: forest,
                backgroundColor: Colors.white,
                onRefresh: _fetchRoomQr,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Room Identity Card
                      _buildRoomCard(),
                      const SizedBox(height: 20),

                      // QR Token Visual Display Card
                      _buildQrDisplayCard(),
                      const SizedBox(height: 24),

                      // Simulator Scan Token QR
                      _buildScannerSimulator(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRoomCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: forest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.meeting_room_rounded, color: Color(0xFFF3E9CF), size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kamar ${_roomNumber ?? widget.currentUser.roomNumber}',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _propertyName ?? widget.currentUser.propertyName,
                      style: const TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 13, color: leaf),
                    SizedBox(width: 4),
                    Text('Terdaftar',
                        style: TextStyle(color: leaf, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              )
            ],
          ),
          if (_roomMembers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: line, height: 1),
            const SizedBox(height: 10),
            const Text(
              'PENGHUNI TERDAFTAR',
              style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in _roomMembers)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F3EE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m is Map ? (m['name']?.toString() ?? 'Penghuni') : m.toString(),
                      style: const TextStyle(color: ink, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildQrDisplayCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: forest, size: 22),
              SizedBox(width: 8),
              Text(
                'Akses Inventaris Kamar',
                style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Spacer(),
              Icon(Icons.shield_outlined, color: leaf, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'QR ini adalah pintu masuk inventaris kamar bersama. Token dienkripsi dan tidak membocorkan kontak pribadi penghuni.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Custom Artistic QR Representation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                // Stylized QR Matrix Pattern
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: line),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Grid pattern
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: 49,
                        itemBuilder: (context, i) {
                          final isCorner = (i < 3 || (i >= 7 && i < 10) || (i >= 14 && i < 17)) ||
                              (i >= 4 && i < 7 || (i >= 11 && i < 14) || (i >= 18 && i < 21)) ||
                              (i >= 28 && i < 31 || (i >= 35 && i < 38) || (i >= 42 && i < 45));
                          final isDot = isCorner || (i % 2 == 0 && i % 3 != 0) || i == 24;
                          return Container(
                            decoration: BoxDecoration(
                              color: isDot ? forest : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                      // Center Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Image.asset('assets/images/icon.png', fit: BoxFit.contain),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Token String Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _qrToken ?? '—',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: forest,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salin Token',
                        icon: const Icon(Icons.copy_rounded, size: 18, color: leaf),
                        onPressed: () {
                          if (_qrToken != null) {
                            Clipboard.setData(ClipboardData(text: _qrToken!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Token QR disalin ke papan klip.'),
                                backgroundColor: forest,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tombol Perbarui Token
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _regenerateToken,
              style: OutlinedButton.styleFrom(
                foregroundColor: forest,
                side: const BorderSide(color: forest),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Perbarui Token QR',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerSimulator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.document_scanner_outlined, color: amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Simulasi Cek Token QR Kamar',
                style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Uji pemindaian QR dengan memasukkan token untuk melihat barang aktif di kamar tanpa membocorkan nomor telepon atau profil privat penghuni.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Token Input field
          TextField(
            controller: _scanTokenController,
            decoration: InputDecoration(
              labelText: 'Token QR Kamar',
              hintText: 'Contoh: ${_qrToken ?? 'KG-RM-08-XXX'}',
              filled: true,
              fillColor: paper,
              suffixIcon: IconButton(
                tooltip: 'Gunakan token saya',
                icon: const Icon(Icons.paste_rounded, size: 18, color: leaf),
                onPressed: () {
                  if (_qrToken != null) {
                    _scanTokenController.text = _qrToken!;
                  }
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: line),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Scan Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _isScanning ? null : _simulateScan,
              style: FilledButton.styleFrom(
                backgroundColor: forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, size: 18),
              label: Text(_isScanning ? 'Memeriksa token…' : 'Periksa Token / Pindai',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),

          // Scan Error
          if (_scanError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_scanError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          // Scan Results
          if (_scanResult != null) ...[
            const SizedBox(height: 16),
            const Divider(color: line, height: 1),
            const SizedBox(height: 14),
            _buildScanResultView(_scanResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildScanResultView(Map<String, dynamic> result) {
    final roomName = result['room_number']?.toString() ??
        (result['room'] is Map ? result['room']['room_number']?.toString() : '—');
    final property = result['property_name']?.toString() ??
        (result['property'] is Map ? result['property']['name']?.toString() : 'Kost Kemuning');

    List<dynamic> items = [];
    if (result['items'] is List) {
      items = result['items'] as List;
    } else if (result['active_items'] is List) {
      items = result['active_items'] as List;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'KAMAR $roomName · $property',
                style: const TextStyle(color: leaf, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            Text('${items.length} Barang Aktif',
                style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Tidak ada barang aktif dari kamar ini di fasilitas bersama saat ini.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          )
        else
          Column(
            children: [
              for (final it in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (it['facility']?.toString().toLowerCase().contains('kulkas') ?? false)
                            ? Icons.kitchen_rounded
                            : Icons.local_laundry_service_rounded,
                        color: leaf,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          it['name']?.toString() ?? 'Barang',
                          style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          it['facility']?.toString() ?? 'Jemuran',
                          style: const TextStyle(color: forest, fontSize: 9.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
