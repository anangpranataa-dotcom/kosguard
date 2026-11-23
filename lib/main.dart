import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'constants/theme.dart';
import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/room_qr_screen.dart';
import 'services/api_service.dart';

export 'constants/theme.dart';
export 'models/models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KosGuardApp());
}

class KosGuardApp extends StatelessWidget {
  const KosGuardApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kosguard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(seedColor: forest, surface: paper),
          fontFamily: 'Roboto',
        ),
        builder: (context, child) => Container(
          color: const Color(0xFFECEAE2),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: const AuthGate(),
      );
}

/// Gatekeeper untuk mengecek autentikasi token saat aplikasi pertama kali dibuka
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  KGUser? _user;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    try {
      final userMap = await ApiService.getMe();
      if (mounted) {
        setState(() {
          _user = KGUser.fromJson(userMap);
          _checking = false;
        });
      }
    } catch (_) {
      await ApiService.clearToken();
      await ApiService.clearUser();
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: paper,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/images/icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: forest, strokeWidth: 2),
            ],
          ),
        ),
      );
    }

    if (_user != null) {
      if (_user!.isOwner) {
        return OwnerDashboardScreen(currentUser: _user!);
      }
      return HomeShell(currentUser: _user);
    }

    return const AuthScreen();
  }
}

class HomeShell extends StatefulWidget {
  final KGUser? currentUser;

  const HomeShell({super.key, this.currentUser});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  String _facility = 'Semua';
  bool _isCapturingPhoto = false;

  bool _isLoading = true;
  String? _errorMessage;

  KGUser? _user;
  List<KGItem> _items = [];
  List<ItemActivity> _activityEvents = [];
  List<KGReport> _reports = [];
  int _unreadNotifications = 0;

  // Sub-tab di halaman Aktivitas: 0 untuk Log Aktivitas, 1 untuk Laporan Kejadian
  int _activitySubTab = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Muat profil user
      final userMap = await ApiService.getMe();
      final user = KGUser.fromJson(userMap);

      // 2. Muat item inventaris
      final rawItems = await ApiService.getItems();
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => KGItem.fromJson(e, currentUserId: user.id))
          .toList();

      // 3. Muat laporan kejadian
      final rawReports = await ApiService.getReports();
      final reports = rawReports
          .whereType<Map<String, dynamic>>()
          .map((e) => KGReport.fromJson(e))
          .toList();

      // 4. Muat status notifikasi
      int unread = 0;
      try {
        final rawNotifs = await ApiService.getNotifications();
        unread = rawNotifs
            .whereType<Map<String, dynamic>>()
            .where((n) => n['read_at'] == null && n['is_read'] != true && n['is_read'] != 1)
            .length;
      } catch (_) {}

      // Ekstrak aktivitas
      final List<ItemActivity> allActivities = [];
      for (final item in items) {
        allActivities.addAll(item.activities);
      }

      if (allActivities.isEmpty && items.isNotEmpty) {
        for (final item in items) {
          allActivities.add(ItemActivity(
            itemName: item.name,
            oldStatus: item.status == ItemStatus.active ? 'REGISTERED' : 'ACTIVE',
            newStatus: item.rawStatus,
            occurredAt: item.createdAt ?? DateTime.now(),
            facility: item.facility,
            room: item.room,
            actor: item.isMine ? 'Kamu' : 'Kamar ${item.room}',
          ));
        }
      }

      if (mounted) {
        setState(() {
          _user = user;
          _items = items;
          _reports = reports;
          _activityEvents = allActivities;
          _unreadNotifications = unread;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      _myItems(),
      _activity(),
      _profile(),
    ];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: forest,
          backgroundColor: Colors.white,
          onRefresh: _loadData,
          child: IndexedStack(index: _tab, children: pages),
        ),
      ),
      bottomNavigationBar: _navigation(),
      floatingActionButton: _tab == 0 || _tab == 1
          ? FloatingActionButton.extended(
              onPressed: _addItem,
              backgroundColor: forest,
              foregroundColor: Colors.white,
              elevation: 1,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Daftarkan barang',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _home() {
    final activeItems = _items.where((i) => i.status == ItemStatus.active);
    final shown = _facility == 'Semua'
        ? activeItems.toList()
        : activeItems.where((i) => i.facility == _facility).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          sliver: SliverToBoxAdapter(child: _topHeader()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
          sliver: SliverToBoxAdapter(child: _greeting()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          sliver: SliverToBoxAdapter(child: _overview()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
          sliver: SliverToBoxAdapter(child: _inventoryHeader()),
        ),
        SliverToBoxAdapter(child: _filters()),
        if (_isLoading && _items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: forest, strokeWidth: 2),
            ),
          )
        else if (_errorMessage != null && _items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _errorView(_errorMessage!),
          )
        else if (shown.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _emptyInventory())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 112),
            sliver: SliverList.separated(
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(height: 11),
              itemBuilder: (_, index) => _itemTile(shown[index]),
            ),
          ),
      ],
    );
  }

  Widget _topHeader() => Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFE5E4DC)),
              ),
              child: Image.asset('assets/images/icon.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          const Text('kosguard',
              style: TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8)),
          const Spacer(),
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              _loadData();
            },
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.notifications_none_rounded,
                  size: 25, color: ink),
              if (_unreadNotifications > 0 || _reports.any((r) => r.isOpen))
                Positioned(
                    right: 0,
                    top: -1,
                    child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: amber, shape: BoxShape.circle))),
            ]),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _tab = 3),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE7E6D9),
              child: Text(
                (_user?.name.isNotEmpty ?? false)
                    ? _user!.name[0].toUpperCase()
                    : 'A',
                style: const TextStyle(
                    color: forest, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );

  Widget _greeting() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 15, color: leaf),
            const SizedBox(width: 4),
            Text(
              '${_user?.propertyName.toUpperCase() ?? 'KOST KEMUNING'}  ·  KAMAR ${_user?.roomNumber ?? '08'}',
              style: const TextStyle(
                  fontSize: 10,
                  color: leaf,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15),
            ),
          ]),
          const SizedBox(height: 11),
          const Text('Ruang bersama,\nlebih terjaga.',
              style: TextStyle(
                  color: ink,
                  fontSize: 31,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.35)),
          const SizedBox(height: 8),
          Text(
            'Halo ${_user?.name ?? 'Penghuni'}, pantau barang bersama dengan aman.',
            style: const TextStyle(color: muted, fontSize: 13.5),
          ),
        ],
      );

  Widget _overview() => Container(
        padding: const EdgeInsets.fromLTRB(19, 18, 18, 18),
        decoration: BoxDecoration(
            color: forest, borderRadius: BorderRadius.circular(21)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Sedang di ruang bersama',
                    style: TextStyle(
                        color: Color(0xFFF6F3E9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF365C4D),
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.shield_outlined,
                    size: 12, color: Color(0xFFD2E0D0)),
                SizedBox(width: 5),
                Text('Data live',
                    style: TextStyle(
                        color: Color(0xFFD2E0D0),
                        fontSize: 10,
                        fontWeight: FontWeight.w500))
              ]),
            ),
          ]),

          const SizedBox(height: 19),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_items.where((i) => i.status == ItemStatus.active).length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 41,
                    height: 0.98,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.8)),
            const Padding(
                padding: EdgeInsets.only(left: 9, bottom: 4),
                child: Text('barang aktif',
                    style: TextStyle(color: Color(0xFFD0DAD0), fontSize: 13))),
            const Spacer(),
            _facilityMini(
                Icons.local_laundry_service_rounded,
                'Jemuran',
                '${_items.where((i) => i.facility == 'Jemuran' && i.status == ItemStatus.active).length}'),
            const SizedBox(width: 20),
            _facilityMini(
                Icons.kitchen_rounded,
                'Kulkas',
                '${_items.where((i) => i.facility == 'Kulkas' && i.status == ItemStatus.active).length}'),
          ]),
        ]),
      );

  Widget _facilityMini(IconData icon, String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: const Color(0xFFCAD9C8)),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700))
        ]),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFFCAD9C8), fontSize: 10)),
      ]);

  Widget _inventoryHeader() =>
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inventaris bersama',
              style: TextStyle(
                  color: ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
          SizedBox(height: 4),
          Text('Terlihat oleh penghuni kost',
              style: TextStyle(color: muted, fontSize: 12)),
        ])),
        ElevatedButton.icon(
            onPressed: _reportItem,
            style: ElevatedButton.styleFrom(
                backgroundColor: amber,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.report_problem_rounded, size: 17),
            label: const Text('Laporkan',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
      ]);

  Widget _filters() => SizedBox(
        height: 39,
        child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: [
              for (final label in ['Semua', 'Jemuran', 'Kulkas'])
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _facility == label,
                      onSelected: (_) => setState(() => _facility = label),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                          color: _facility == label
                              ? Colors.white
                              : const Color(0xFF68756D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      backgroundColor: const Color(0xFFF0EFE8),
                      selectedColor: forest,
                      side: BorderSide(
                          color: _facility == label
                              ? forest
                              : const Color(0xFFE8E7DE)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                    )),
            ]),
      );

  Widget _itemTile(KGItem item) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _showItem(item),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFECEBE4))),
            child: Row(children: [
              _itemArt(item),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      if (item.isMine)
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE7EDE4),
                              borderRadius: BorderRadius.circular(5)),
                          child: const Text('Milikmu',
                              style: TextStyle(
                                  color: forest,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      _status(item)
                    ]),
                    const SizedBox(height: 5),
                    Text(
                      '${KGItem.formatCategoryLabel(item.category)}  ·  Kamar ${item.room}',
                      style: const TextStyle(color: muted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 9),
                    Row(children: [
                      Icon(
                          item.facility == 'Jemuran'
                              ? Icons.local_laundry_service_rounded
                              : Icons.kitchen_rounded,
                          size: 13,
                          color: leaf),
                      const SizedBox(width: 5),
                      Text(item.facility,
                          style: const TextStyle(
                              color: Color(0xFF52645A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600)),
                      if (item.status == ItemStatus.active) ...[
                        const Spacer(),
                        Icon(Icons.schedule_rounded,
                            size: 12,
                            color: item.remaining.contains('jam') ||
                                    item.remaining.contains('mnt')
                                ? amber
                                : muted),
                        const SizedBox(width: 4),
                        Text(item.remaining,
                            style: TextStyle(
                                color: item.remaining.contains('jam') ||
                                        item.remaining.contains('mnt')
                                    ? const Color(0xFFA86C2C)
                                    : muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500))
                      ]
                    ]),
                  ])),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 19, color: Color(0xFFAEB5AD)),
            ]),
          ),
        ),
      );

  IconData _smartItemIcon(KGItem item) {
    final name = item.name.toLowerCase();
    final cat = item.category.toLowerCase();

    // 1. Minuman, termos, botol, kopi/teh
    if (name.contains('kopi') ||
        name.contains('teh') ||
        name.contains('mug') ||
        name.contains('cangkir') ||
        name.contains('gelas')) {
      return Icons.local_cafe_rounded;
    }
    if (name.contains('termos') ||
        name.contains('botol') ||
        name.contains('tumbler') ||
        name.contains('air') ||
        name.contains('minum') ||
        name.contains('galon') ||
        name.contains('susu') ||
        name.contains('jus') ||
        name.contains('sirup')) {
      return Icons.local_drink_rounded;
    }

    // 2. Makanan spesifik (daging, sayur/buah, roti, nasi/mie, dessert)
    if (name.contains('daging') ||
        name.contains('ayam') ||
        name.contains('ikan') ||
        name.contains('telur') ||
        name.contains('sosis') ||
        name.contains('nugget') ||
        name.contains('udang') ||
        name.contains('seafood')) {
      return Icons.set_meal_rounded;
    }
    if (name.contains('nasi') ||
        name.contains('mie') ||
        name.contains('mi ') ||
        name.contains('bubur') ||
        name.contains('bakso') ||
        name.contains('soto') ||
        name.contains('sup')) {
      return Icons.rice_bowl_rounded;
    }
    if (name.contains('sayur') ||
        name.contains('buah') ||
        name.contains('apel') ||
        name.contains('pisang') ||
        name.contains('jeruk') ||
        name.contains('alpukat') ||
        name.contains('tomat') ||
        name.contains('cabai')) {
      return Icons.eco_rounded;
    }
    if (name.contains('roti') ||
        name.contains('kue') ||
        name.contains('donat') ||
        name.contains('biskuit') ||
        name.contains('bolu')) {
      return Icons.bakery_dining_rounded;
    }
    if (name.contains('es ') ||
        name.contains('es krim') ||
        name.contains('puding') ||
        name.contains('yogurt')) {
      return Icons.icecream_rounded;
    }

    // 3. Pakaian, handuk/sprei, tas, payung
    if (name.contains('handuk') ||
        name.contains('selimut') ||
        name.contains('sprei') ||
        name.contains('sarung') ||
        name.contains('bantal') ||
        name.contains('keset')) {
      return Icons.dry_cleaning_rounded;
    }
    if (name.contains('kemeja') ||
        name.contains('baju') ||
        name.contains('kaos') ||
        name.contains('jaket') ||
        name.contains('hoodie') ||
        name.contains('sweater') ||
        name.contains('celana') ||
        name.contains('rok') ||
        name.contains('gamis') ||
        name.contains('hijab') ||
        name.contains('kerudung') ||
        name.contains('jilbab') ||
        name.contains('seragam')) {
      return Icons.checkroom_rounded;
    }
    if (name.contains('tas') ||
        name.contains('ransel') ||
        name.contains('dompet')) {
      return Icons.backpack_rounded;
    }
    if (name.contains('payung') || name.contains('jas hujan')) {
      return Icons.umbrella_rounded;
    }

    // 4. Alat makan/dapur, elektronik, perlengkapan mandi
    if (name.contains('piring') ||
        name.contains('mangkok') ||
        name.contains('mangkuk') ||
        name.contains('sendok') ||
        name.contains('garpu') ||
        name.contains('bekal') ||
        name.contains('tupperware') ||
        name.contains('wadah')) {
      return Icons.flatware_rounded;
    }
    if (name.contains('charger') ||
        name.contains('kabel') ||
        name.contains('powerbank') ||
        name.contains('headset') ||
        name.contains('earphone') ||
        name.contains('kipas') ||
        name.contains('setrika')) {
      return Icons.electrical_services_rounded;
    }
    if (name.contains('sabun') ||
        name.contains('shampo') ||
        name.contains('sampo') ||
        name.contains('skincare') ||
        name.contains('parfum')) {
      return Icons.spa_rounded;
    }

    // 5. Fallback berdasarkan kategori
    if (cat.contains('pakaian')) return Icons.checkroom_rounded;
    if (cat.contains('makanan')) return Icons.lunch_dining_rounded;
    if (cat.contains('minuman')) return Icons.local_drink_rounded;
    if (cat.contains('elektronik')) return Icons.electrical_services_rounded;

    return Icons.inventory_2_rounded;
  }

  Widget _itemArt(KGItem item) {
    final normalizedUrl = ApiService.resolveImageUrl(item.photoUrl);

    Widget artPlaceholder() => Stack(alignment: Alignment.center, children: [
          Positioned(
              top: 8,
              right: 8,
              child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: item.artColor.withValues(alpha: .10),
                      shape: BoxShape.circle))),
          Icon(_smartItemIcon(item), color: item.artColor, size: 29),
        ]);

    Widget imageContent;
    if (item.photoBytes != null && item.photoBytes!.isNotEmpty) {
      imageContent = Image.memory(item.photoBytes!, fit: BoxFit.cover);
    } else if (item.photoPath != null &&
        !kIsWeb &&
        File(item.photoPath!).existsSync()) {
      imageContent = Image.file(File(item.photoPath!), fit: BoxFit.cover);
    } else if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      imageContent = Image.network(
        normalizedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => artPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: item.artBg,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: forest),
              ),
            ),
          );
        },
      );
    } else {
      imageContent = artPlaceholder();
    }

    return Container(
      width: 59,
      height: 64,
      decoration: BoxDecoration(
          color: item.artBg, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: imageContent,
    );
  }
  
  Widget _status(KGItem item) {
    final isActive = item.status == ItemStatus.active;
    final isExpired = item.isExpired;

    Color bg = const Color(0xFFECECE6);
    Color textColor = muted;
    String label = item.rawStatus;

    if (isActive) {
      bg = const Color(0xFFEAF1E9);
      textColor = leaf;
      label = 'Aktif';
    } else if (isExpired) {
      bg = const Color(0xFFFFF4E5);
      textColor = amber;
      label = 'Habis';
    } else {
      label = 'Diambil';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: textColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _emptyInventory() => Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: Color(0xFFECEFE7), shape: BoxShape.circle),
              child: const Icon(Icons.inventory_2_outlined,
                  color: leaf, size: 24)),
          const SizedBox(height: 14),
          const Text('Belum ada barang di sini',
              style: TextStyle(
                  color: ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Pilih fasilitas lain atau daftarkan barang saat menitipkannya.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
        ]),
      );

  Widget _errorView(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: amber),
              const SizedBox(height: 12),
              const Text(
                'Tidak dapat terhubung ke server',
                style: TextStyle(
                    color: ink, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadData,
                style: FilledButton.styleFrom(
                    backgroundColor: forest, foregroundColor: Colors.white),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              )
            ],
          ),
        ),
      );

  Widget _navigation() => NavigationBar(
        height: 68,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFFFCFBF8),
        indicatorColor: const Color(0xFFE7EDE4),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Barang saya'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Aktivitas'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil'),
        ],
      );

  Widget _myItems() {
    final myItems = _items.where((item) => item.isMine).toList();
    return _secondaryPage(
      title: 'Barang saya',
      subtitle: 'Barang yang kamu daftarkan di ruang bersama.',
      child: _isLoading && _items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: forest, strokeWidth: 2),
            )
          : myItems.isEmpty
              ? _emptyInventory()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 112),
                  itemCount: myItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 11),
                  itemBuilder: (_, i) => _itemTile(myItems[i]),
                ),
    );
  }

  Widget _activity() {
    final events = _activityEvents.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return _secondaryPage(
      title: 'Aktivitas',
      subtitle: 'Riwayat status barang dan laporan kejadian.',
      child: Column(
        children: [
          // Sub-Tab Switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEBE9E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activitySubTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activitySubTab == 0
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'Log Status (${events.length})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _activitySubTab == 0 ? ink : muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activitySubTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activitySubTab == 1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Laporan (${_reports.length})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _activitySubTab == 1 ? ink : muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_reports.any((r) => r.isOpen)) ...[
                              const SizedBox(width: 5),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _activitySubTab == 0
                ? (events.isEmpty
                    ? _activityEmptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(22, 2, 22, 40),
                        children: [
                          for (var index = 0; index < events.length; index++)
                            _activityEntry(events[index],
                                isLast: index == events.length - 1),
                        ],
                      ))
                : _reportsList(),
          ),
        ],
      ),
    );
  }

  Widget _reportsList() {
    if (_reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: Color(0xFFECEFE7), shape: BoxShape.circle),
                child: const Icon(Icons.assignment_turned_in_outlined,
                    color: leaf, size: 24),
              ),
              const SizedBox(height: 14),
              const Text('Tidak ada laporan terbuka',
                  style: TextStyle(
                      color: ink, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Semua barang dan situasi di kost dalam kondisi aman.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (_, index) {
        final report = _reports[index];
        final isOpen = report.isOpen;
        final isUnderReview = report.isUnderReview;

        Color badgeBg = const Color(0xFFEAF1E9);
        Color badgeText = leaf;
        String statusLabel = 'SELESAI';

        if (isOpen) {
          badgeBg = const Color(0xFFFFF4E5);
          badgeText = amber;
          statusLabel = 'TERBUKA';
        } else if (isUnderReview) {
          badgeBg = const Color(0xFFFEF3C7);
          badgeText = const Color(0xFFA86C2C);
          statusLabel = 'DITINJAU';
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? amber.withValues(alpha: 0.15)
                          : const Color(0xFFEAF1E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      report.kindLabel.toUpperCase(),
                      style: TextStyle(
                        color: isOpen ? const Color(0xFFA86C2C) : leaf,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: badgeText,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (report.itemName != null && report.itemName!.isNotEmpty) ...[
                Text(
                  report.itemName!,
                  style: const TextStyle(
                      color: ink, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                report.notes,
                style: const TextStyle(color: Color(0xFF49544D), fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined,
                      size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    '${report.reporterName} (Kmr ${report.roomNumber})',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  const Spacer(),
                  Text(
                    _formatActivityTime(report.createdAt),
                    style: const TextStyle(color: muted, fontSize: 10.5),
                  ),
                ],
              ),
              if (!report.isResolved) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _claimItemModal(report),
                        style: FilledButton.styleFrom(
                          backgroundColor: forest,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                        label: const Text('Ajukan Klaim Kepemilikan',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _claimItemModal(KGReport report) {
    final privateDetailsController = TextEditingController();
    Uint8List? claimEvidenceBytes;
    String? claimEvidenceName;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Ajukan Klaim Kepemilikan',
                  style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Laporan: ${report.kindLabel} (${report.itemName ?? 'Barang'})',
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: privateDetailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Detail Rahasia Kepemilikan',
                    hintText:
                        'Tulis ciri yang hanya kamu ketahui (misal: ada noda di kerah dalam, robekan kecil, struk pembelian, dsb.).',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: line),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Foto Bukti Klaim
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      setSheet(() {
                        claimEvidenceBytes = bytes;
                        claimEvidenceName = photo.name;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          claimEvidenceBytes != null ? Icons.check_circle_rounded : Icons.photo_camera_outlined,
                          color: claimEvidenceBytes != null ? forest : muted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            claimEvidenceBytes != null
                                ? 'Foto bukti terpilih (${claimEvidenceName ?? 'foto.jpg'})'
                                : 'Unggah foto bukti tambahan (opsional)',
                            style: TextStyle(
                              color: claimEvidenceBytes != null ? ink : muted,
                              fontSize: 12,
                              fontWeight: claimEvidenceBytes != null ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final details = privateDetailsController.text.trim();
                            if (details.isEmpty) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(content: Text('Detail rahasia wajib diisi.')),
                              );
                              return;
                            }

                            setSheet(() => isSubmitting = true);
                            try {
                              await ApiService.submitClaim(
                                report.id,
                                privateDetails: details,
                                evidenceBytes: claimEvidenceBytes,
                                evidenceFileName: claimEvidenceName,
                              );

                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Klaim kepemilikan berhasil diajukan untuk ditinjau.'),
                                  backgroundColor: forest,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              _loadData();
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              setSheet(() => isSubmitting = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: forest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Kirim Pengajuan Klaim', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(privateDetailsController.dispose);
  }

  Widget _activityEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: Color(0xFFECEFE7), shape: BoxShape.circle),
                child: const Icon(Icons.history_rounded, color: leaf, size: 24),
              ),
              const SizedBox(height: 14),
              const Text('Belum ada catatan aktivitas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ink, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                  'Daftarkan barang dan mulai sesi fasilitas untuk membuat riwayat status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
              const SizedBox(height: 17),
              FilledButton.icon(
                  onPressed: _addItem,
                  style: FilledButton.styleFrom(
                      backgroundColor: forest, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Daftarkan barang')),
            ],
          ),
        ),
      );

  Widget _activityEntry(ItemActivity event, {required bool isLast}) =>
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 34,
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                    color: Color(0xFFEAF1E9), shape: BoxShape.circle),
                child:
                    Icon(_activityIcon(event.newStatus), size: 15, color: leaf),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFDDE4D9)),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: line)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(_activityTitle(event.newStatus),
                                  style: const TextStyle(
                                      color: ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(_formatActivityTime(event.occurredAt),
                                style: const TextStyle(
                                    color: muted, fontSize: 9.5)),
                          ]),
                      const SizedBox(height: 4),
                      Text(event.itemName,
                          style: const TextStyle(
                              color: Color(0xFF56635A), fontSize: 11.5)),
                      const SizedBox(height: 9),
                      Row(children: [
                        _statusCode(event.oldStatus),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 12, color: muted)),
                        _statusCode(event.newStatus),
                      ]),
                      const SizedBox(height: 9),
                      Row(children: [
                        Icon(
                            event.facility == 'Jemuran'
                                ? Icons.local_laundry_service_rounded
                                : Icons.kitchen_rounded,
                            size: 13,
                            color: leaf),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(
                                '${event.facility} · Kamar ${event.room} · ${event.actor}',
                                style: const TextStyle(
                                    color: muted, fontSize: 10.5))),
                      ]),
                    ]),
              ),
            ),
          ),
        ]),
      );

  Widget _statusCode(String status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F1EB),
            borderRadius: BorderRadius.circular(5)),
        child: Text(status,
            style: const TextStyle(
                color: Color(0xFF58665D),
                fontSize: 8.5,
                fontWeight: FontWeight.w700)),
      );

  IconData _activityIcon(String status) => switch (status.toUpperCase()) {
        'ACTIVE' => Icons.place_outlined,
        'RETRIEVED' => Icons.check_circle_outline_rounded,
        'EXPIRED' => Icons.schedule_rounded,
        'MISSING' => Icons.search_off_rounded,
        'SWAPPED' => Icons.swap_horiz_rounded,
        'FOUND' => Icons.inventory_2_outlined,
        'RETURNED' => Icons.assignment_return_outlined,
        _ => Icons.add_box_outlined,
      };

  String _activityTitle(String status) => switch (status.toUpperCase()) {
        'ACTIVE' => 'Sesi ruang bersama dimulai',
        'RETRIEVED' => 'Barang sudah diambil',
        'EXPIRED' => 'Sesi fasilitas berakhir',
        'MISSING' => 'Barang dilaporkan hilang',
        'SWAPPED' => 'Barang dilaporkan tertukar',
        'FOUND' => 'Barang temuan dilaporkan',
        'RETURNED' => 'Barang dikembalikan',
        _ => 'Barang didaftarkan',
      };

  String _formatActivityTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes} mnt lalu';
    if (difference.inDays == 0) return 'Hari ini · $clock';
    if (difference.inDays == 1) return 'Kemarin · $clock';
    return '${time.day}/${time.month}/${time.year} · $clock';
  }

  Widget _profile() => _secondaryPage(
        title: 'Profil',
        subtitle: 'Akun dan preferensi kost.',
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: line)),
                child: Row(children: [
                  CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE7E6D9),
                      child: Text(
                          (_user?.name.isNotEmpty ?? false)
                              ? _user!.name[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                              color: forest, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_user?.name ?? 'Penghuni kost',
                              style: const TextStyle(
                                  color: ink, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                              'Kamar ${_user?.roomNumber ?? '08'} · ${_user?.propertyName ?? 'Kost Kemuning'}',
                              style: const TextStyle(
                                  color: muted, fontSize: 12)),
                        ]),
                  ),
                ])),
            const SizedBox(height: 13),
            _profileRow(
              Icons.lock_outline_rounded,
              'Privasi & visibilitas',
              'Data pribadi tetap terlindungi',
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: paper,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  title: const Text('Privasi & Visibilitas',
                      style: TextStyle(
                          color: ink, fontWeight: FontWeight.w700)),
                  content: const Text(
                    'Inventaris bersama hanya menampilkan foto barang, '
                    'kategori, dan nomor kamar pemilik.\n\n'
                    'Kontak pribadi penghuni, detail klaim kepemilikan, '
                    'dan ciri khusus rahasia hanya dapat dilihat oleh '
                    'pengelola kost.',
                    style: TextStyle(color: muted, fontSize: 13, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Mengerti',
                          style: TextStyle(
                              color: forest, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            _profileRow(
              Icons.qr_code_2_rounded,
              'QR kamar',
              'Akses inventaris kamar ${_user?.roomNumber ?? '08'}',
              onTap: () {
                if (_user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomQrScreen(currentUser: _user!),
                    ),
                  );
                }
              },
            ),
            _profileRow(
              Icons.help_outline_rounded,
              'Bantuan',
              'Panduan penggunaan Kosguard',
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: paper,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  title: const Text('Panduan Kosguard',
                      style: TextStyle(
                          color: ink, fontWeight: FontWeight.w700)),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Daftarkan barang',
                          style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        'Ketuk tombol tambah, pilih fasilitas: '
                        'Jemuran (otomatis 48 jam), '
                        'Kulkas bahan mentah (7 hari / 168 jam), '
                        'atau Kulkas makanan matang (10 hari / 240 jam).',
                        style:
                            TextStyle(color: muted, fontSize: 12.5, height: 1.5),
                      ),
                      SizedBox(height: 12),
                      Text('2. Tandai sudah diambil',
                          style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        'Buka tab "Barang saya", ketuk barang yang ingin '
                        'ditandai, lalu pilih "Tandai sudah diambil".',
                        style:
                            TextStyle(color: muted, fontSize: 12.5, height: 1.5),
                      ),
                      SizedBox(height: 12),
                      Text('3. Laporkan kejadian',
                          style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        'Ketuk tombol "Laporkan" di tab Beranda, '
                        'pilih jenis kejadian (Hilang, Tertukar, atau Barang Temuan), '
                        'lalu isi detail dan unggah bukti foto.',
                        style:
                            TextStyle(color: muted, fontSize: 12.5, height: 1.5),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup',
                          style: TextStyle(
                              color: forest, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Tombol Logout
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Keluar (Logout)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ]),
        ),
      );

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Keluar dari Kosguard?',
            style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
        content: const Text(
            'Anda perlu masuk kembali untuk mengakses inventaris kost.',
            style: TextStyle(color: muted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Widget _profileRow(
    IconData icon,
    String title,
    String detail, {
    VoidCallback? onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
              margin: const EdgeInsets.only(top: 9),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: line)),
              child: Row(children: [
                Icon(icon, size: 19, color: leaf),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(detail,
                          style: const TextStyle(color: muted, fontSize: 10.5))
                    ])),
                const Icon(Icons.chevron_right_rounded, size: 19, color: muted)
              ])),
        ),
      );

  Widget _secondaryPage(
          {required String title,
          required String subtitle,
          required Widget child}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: ink,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(color: muted, fontSize: 12.5))
                  ])),
              ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0xFFE5E4DC)),
                      ),
                      child: Image.asset('assets/images/icon.png', fit: BoxFit.contain))),
            ])),
        Expanded(child: child),
      ]);

  // Modal Pendaftaran Barang dengan Kebijakan Durasi Otomatis PRD
  void _addItem() {
    final nameController = TextEditingController();
    final colorController = TextEditingController();
    final brandController = TextEditingController();
    final marksController = TextEditingController();

    String facility = 'Jemuran';
    String category = 'Pakaian';
    int durationHours = 48; // Jemuran otomatis 48 jam
    Uint8List? capturedBytes;
    String? capturedFileName;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheet) => Padding(
                padding: EdgeInsets.fromLTRB(
                    22, 12, 22, MediaQuery.of(context).viewInsets.bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 35,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFD6D6CE),
                                    borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 22),
                        const Text('Daftarkan barang',
                            style: TextStyle(
                                color: ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.6)),
                        const SizedBox(height: 5),
                        const Text('Kebijakan durasi ruang bersama dihitung otomatis.',
                            style: TextStyle(color: muted, fontSize: 12.5)),
                        const SizedBox(height: 19),
                        _photoCaptureBox(
                          setSheet,
                          sheetContext,
                          capturedBytes,
                          (bytes, name) {
                            setSheet(() {
                              capturedBytes = bytes;
                              capturedFileName = name;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        TextField(
                            controller: nameController,
                            autofocus: false,
                            decoration: InputDecoration(
                                labelText: 'Nama barang *',
                                hintText: 'Contoh: Jaket denim',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(color: line)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide:
                                        const BorderSide(color: line)))),
                        const SizedBox(height: 16),
                        const Text('Pilih Ruang Bersama',
                            style: TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(children: [
                          for (final f in ['Jemuran', 'Kulkas'])
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.only(
                                        right: f == 'Jemuran' ? 8 : 0),
                                    child: ChoiceChip(
                                        label: Text(f),
                                        selected: facility == f,
                                        onSelected: (_) => setSheet(() {
                                              facility = f;
                                              if (f == 'Jemuran') {
                                                category = 'Pakaian';
                                                durationHours = 48;
                                              } else {
                                                category = 'RAW';
                                                durationHours = 168; // 7 hari
                                              }
                                            }),
                                        showCheckmark: false,
                                        labelStyle: TextStyle(
                                            color: facility == f
                                                ? Colors.white
                                                : muted,
                                            fontWeight: FontWeight.w600),
                                        backgroundColor: Colors.white,
                                        selectedColor: forest,
                                        side: BorderSide(
                                            color: facility == f
                                                ? forest
                                                : line),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8))))
                        ]),
                        const SizedBox(height: 16),

                        // Kategori & Kebijakan Durasi Otomatis sesuai PRD
                        if (facility == 'Jemuran') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1E9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD2E0D0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 18, color: leaf),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Durasi otomatis jemuran: 48 jam (sesuai kebijakan kost)',
                                    style: TextStyle(
                                      color: forest,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const Text('Kategori Bahan Makanan',
                              style: TextStyle(
                                  color: ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Bahan Mentah (RAW) · 7 hari / 168 jam'),
                                selected: category == 'RAW',
                                onSelected: (_) => setSheet(() {
                                  category = 'RAW';
                                  durationHours = 168;
                                }),
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: category == 'RAW' ? Colors.white : muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                                backgroundColor: Colors.white,
                                selectedColor: forest,
                                side: BorderSide(color: category == 'RAW' ? forest : line),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              ChoiceChip(
                                label: const Text('Makanan Instan & Matang (INSTANT) · 10 hari / 240 jam'),
                                selected: category == 'INSTANT',
                                onSelected: (_) => setSheet(() {
                                  category = 'INSTANT';
                                  durationHours = 240;
                                }),
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: category == 'INSTANT' ? Colors.white : muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                                backgroundColor: Colors.white,
                                selectedColor: forest,
                                side: BorderSide(color: category == 'INSTANT' ? forest : line),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),
                        // Field Tambahan Sesuai PRD (Color, Brand, Marks)
                        const Text('Detail Tambahan (Opsional)',
                            style: TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: colorController,
                                decoration: InputDecoration(
                                  labelText: 'Warna',
                                  hintText: 'Misal: Biru tua',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: line)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: line)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: brandController,
                                decoration: InputDecoration(
                                  labelText: 'Merek',
                                  hintText: 'Misal: Uniqlo / Tupperware',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: line)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: line)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: marksController,
                          decoration: InputDecoration(
                            labelText: 'Ciri Khusus / Label Nama',
                            hintText: 'Misal: Ada stiker nama di tutup botol',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: line)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: line)),
                          ),
                        ),
                        const SizedBox(height: 22),

                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final name = nameController.text.trim();
                                        if (name.isEmpty) {
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Silakan masukkan nama barang.')));
                                          return;
                                        }

                                        setSheet(() => isSubmitting = true);

                                        try {
                                          await ApiService.createItem(
                                            name: name,
                                            category: category,
                                            facility: facility,
                                            durationHours: durationHours,
                                            photoBytes: capturedBytes,
                                            photoFileName: capturedFileName,
                                            color: colorController.text.trim(),
                                            brand: brandController.text.trim(),
                                            distinctiveMarks:
                                                marksController.text.trim(),
                                          );

                                          if (!sheetContext.mounted) return;
                                          Navigator.pop(sheetContext);

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                '$name berhasil didaftarkan ke $facility.'),
                                            backgroundColor: forest,
                                            behavior:
                                                SnackBarBehavior.floating,
                                          ));

                                          _loadData();
                                        } catch (e) {
                                          if (!sheetContext.mounted) return;
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(SnackBar(
                                            content: Text(e
                                                .toString()
                                                .replaceAll('Exception: ', '')),
                                            backgroundColor:
                                                Colors.red.shade700,
                                          ));
                                          setSheet(() => isSubmitting = false);
                                        }
                                      },
                                style: FilledButton.styleFrom(
                                    backgroundColor: forest,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Simpan barang',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)))),
                      ]),
                ),
              )),
    ).whenComplete(() {
      nameController.dispose();
      colorController.dispose();
      brandController.dispose();
      marksController.dispose();
    });
  }

  Widget _photoCaptureBox(
    StateSetter setSheet,
    BuildContext sheetContext,
    Uint8List? photoBytes,
    Function(Uint8List, String) onCaptured,
  ) {
    return InkWell(
      onTap: _isCapturingPhoto
          ? null
          : () async {
              final source = await showDialog<ImageSource>(
                context: sheetContext,
                builder: (ctx) => AlertDialog(
                  backgroundColor: paper,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Pilih Sumber Foto',
                      style: TextStyle(
                          color: ink, fontWeight: FontWeight.w700)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.camera_alt_outlined,
                            color: forest),
                        title: const Text('Kamera',
                            style: TextStyle(color: ink)),
                        onTap: () =>
                            Navigator.pop(ctx, ImageSource.camera),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.photo_library_outlined,
                            color: forest),
                        title: const Text('Galeri Foto',
                            style: TextStyle(color: ink)),
                        onTap: () =>
                            Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              );
              if (source == null) return;
              setSheet(() => _isCapturingPhoto = true);
              try {
                final photo = await ImagePicker().pickImage(
                  source: source,
                  imageQuality: 85,
                  maxWidth: 1600,
                );
                if (photo != null) {
                  final bytes = await photo.readAsBytes();
                  onCaptured(bytes, photo.name);
                }
              } catch (_) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                    content: Text('Foto tidak dapat dibuka. Periksa izin kamera atau galeri.'),
                  ));
                }
              } finally {
                if (sheetContext.mounted) {
                  setSheet(() => _isCapturingPhoto = false);
                }
              }
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 154,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFECEFE7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDE4D9)),
        ),
        child: photoBytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: _isCapturingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: forest),
                          )
                        : const Icon(Icons.camera_alt_outlined,
                            color: forest, size: 21),
                  ),
                  const SizedBox(height: 10),
                  Text(
                      _isCapturingPhoto
                          ? 'Membuka…'
                          : 'Ambil atau pilih foto',
                      style: const TextStyle(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  const Text('Kamera atau galeri foto.',
                      style: TextStyle(color: muted, fontSize: 10.5)),
                ],
              )
            : Stack(fit: StackFit.expand, children: [
                Image.memory(photoBytes, fit: BoxFit.cover),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: forest,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh_rounded,
                          size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Ambil ulang',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }

  void _showItem(KGItem item) {
    bool isRetrieving = false;
    bool isReactivating = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModal) => Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _itemArt(item),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.name,
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              '${KGItem.formatCategoryLabel(item.category)} · Kamar ${item.room}',
                              style: const TextStyle(color: muted, fontSize: 12),
                            )
                          ])),
                      _status(item)
                    ]),
                    const SizedBox(height: 18),
                    const Divider(color: line),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.place_outlined, size: 17, color: leaf),
                      const SizedBox(width: 9),
                      Text('Berada di ${item.facility}',
                          style: const TextStyle(
                              color: ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600))
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(
                          item.status == ItemStatus.active
                              ? Icons.schedule_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 17,
                          color: leaf),
                      const SizedBox(width: 9),
                      Text(
                          item.status == ItemStatus.active
                              ? 'Sisa sesi: ${item.remaining}'
                              : (item.isExpired
                                  ? 'Sesi berakhir otomatis'
                                  : 'Sesi selesai karena barang sudah diambil'),
                          style: const TextStyle(color: ink, fontSize: 12.5))
                    ]),
                    if (item.color != null || item.brand != null || item.distinctiveMarks != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.color != null && item.color!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('Warna: ${item.color}',
                                    style: const TextStyle(color: ink, fontSize: 12)),
                              ),
                            if (item.brand != null && item.brand!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('Merek: ${item.brand}',
                                    style: const TextStyle(color: ink, fontSize: 12)),
                              ),
                            if (item.distinctiveMarks != null && item.distinctiveMarks!.isNotEmpty)
                              Text('Ciri khusus: ${item.distinctiveMarks}',
                                  style: const TextStyle(color: ink, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (item.isMine && item.id != null) ...[
                      // Tombol Tandai Sudah Diambil
                      if (item.status == ItemStatus.active)
                        SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton.icon(
                                onPressed: isRetrieving
                                    ? null
                                    : () async {
                                        setModal(() => isRetrieving = true);
                                        try {
                                          await ApiService.retrieveItem(item.id!);
                                          if (!sheetContext.mounted) return;
                                          Navigator.pop(sheetContext);

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      '${item.name} berhasil ditandai sudah diambil.'),
                                                  backgroundColor: forest,
                                                  behavior:
                                                      SnackBarBehavior.floating));
                                          _loadData();
                                        } catch (e) {
                                          if (!sheetContext.mounted) return;
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(SnackBar(
                                            content: Text(e.toString().replaceAll(
                                                'Exception: ', '')),
                                            backgroundColor: Colors.red.shade700,
                                          ));
                                          setModal(() => isRetrieving = false);
                                        }
                                      },
                                style: FilledButton.styleFrom(
                                    backgroundColor: forest,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13))),
                                icon: isRetrieving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_rounded),
                                label: const Text('Tandai sudah diambil'))),

                      // Tombol Aktifkan Sesi Lagi (untuk retrieved / expired)
                      if (item.canReactivate) ...[
                        SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton.icon(
                                onPressed: isReactivating
                                    ? null
                                    : () async {
                                        setModal(() => isReactivating = true);
                                        final int dur = item.facility == 'Jemuran'
                                            ? 48
                                            : (item.category == 'RAW' ? 168 : 240);
                                        try {
                                          await ApiService.reactivateItem(
                                            item.id!,
                                            facility: item.facility,
                                            durationHours: dur,
                                            category: item.category,
                                          );
                                          if (!sheetContext.mounted) return;
                                          Navigator.pop(sheetContext);

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Sesi fasilitas untuk ${item.name} berhasil diaktifkan kembali.'),
                                                  backgroundColor: forest,
                                                  behavior:
                                                      SnackBarBehavior.floating));
                                          _loadData();
                                        } catch (e) {
                                          if (!sheetContext.mounted) return;
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(SnackBar(
                                            content: Text(e.toString().replaceAll(
                                                'Exception: ', '')),
                                            backgroundColor: Colors.red.shade700,
                                          ));
                                          setModal(() => isReactivating = false);
                                        }
                                      },
                                style: FilledButton.styleFrom(
                                    backgroundColor: leaf,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13))),
                                icon: isReactivating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.replay_rounded),
                                label: const Text('Aktifkan Sesi Lagi'))),
                      ],

                      const SizedBox(height: 10),
                      // Tombol Edit Detail
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _editItemModal(item);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: forest,
                            side: const BorderSide(color: forest),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Detail Barang',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ]),
            ),
        ),
      ),
    );
  }

  void _editItemModal(KGItem item) {
    final nameController = TextEditingController(text: item.name);
    final colorController = TextEditingController(text: item.color ?? '');
    final brandController = TextEditingController(text: item.brand ?? '');
    final marksController = TextEditingController(text: item.distinctiveMarks ?? '');
    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Edit Detail Barang',
                  style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Barang',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: colorController,
                        decoration: InputDecoration(
                          labelText: 'Warna',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: brandController,
                        decoration: InputDecoration(
                          labelText: 'Merek',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: marksController,
                  decoration: InputDecoration(
                    labelText: 'Ciri Khusus',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            setSheet(() => isSaving = true);
                            try {
                              await ApiService.updateItem(
                                item.id!,
                                name: name,
                                color: colorController.text.trim(),
                                brand: brandController.text.trim(),
                                distinctiveMarks: marksController.text.trim(),
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Detail barang berhasil diperbarui.'),
                                  backgroundColor: forest,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              _loadData();
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              setSheet(() => isSaving = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: forest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Perubahan',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      colorController.dispose();
      brandController.dispose();
      marksController.dispose();
    });
  }

  void _reportItem() {
    String kind = 'MISSING';
    final detailsController = TextEditingController();
    KGItem? selectedItem;
    Uint8List? evidenceBytes;
    String? evidenceName;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheet) => Padding(
                padding: EdgeInsets.fromLTRB(
                    22, 12, 22, MediaQuery.of(context).viewInsets.bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 35,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFD6D6CE),
                                    borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 22),
                        const Text('Laporkan kejadian',
                            style: TextStyle(
                                color: ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.6)),
                        const SizedBox(height: 5),
                        const Text(
                            'Ceritakan secara netral agar penghuni lain bisa membantu.',
                            style: TextStyle(color: muted, fontSize: 12.5)),
                        const SizedBox(height: 17),
                        Wrap(spacing: 8, children: [
                          for (final option in [
                            {'id': 'MISSING', 'label': 'Hilang'},
                            {'id': 'SWAPPED', 'label': 'Tertukar'},
                            {'id': 'FOUND', 'label': 'Barang temuan'},
                          ])
                            ChoiceChip(
                                label: Text(option['label']!),
                                selected: kind == option['id'],
                                onSelected: (_) =>
                                    setSheet(() => kind = option['id']!),
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                    color: kind == option['id']
                                        ? Colors.white
                                        : muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11),
                                backgroundColor: Colors.white,
                                selectedColor: forest,
                                side: BorderSide(
                                    color: kind == option['id']
                                        ? forest
                                        : line),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 7))
                        ]),
                        if (_items.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<KGItem?>(
                            initialValue: selectedItem,
                            decoration: InputDecoration(
                              labelText: 'Barang terkait (Opsional)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: const BorderSide(color: line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: const BorderSide(color: line),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<KGItem?>(
                                value: null,
                                child: Text('Tidak ditautkan ke barang spesifik',
                                    style: TextStyle(fontSize: 13, color: muted)),
                              ),
                              for (final it in _items)
                                DropdownMenuItem<KGItem?>(
                                  value: it,
                                  child: Text('${it.name} (Kmr ${it.room})',
                                      style: const TextStyle(fontSize: 13)),
                                ),
                            ],
                            onChanged: (val) => setSheet(() => selectedItem = val),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                            controller: detailsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                                labelText: 'Detail kejadian *',
                                hintText: 'Barang terakhir terlihat di…',
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(color: line)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide:
                                        const BorderSide(color: line)))),
                        const SizedBox(height: 12),
                        // Unggah Bukti Insiden (Opsional)
                        InkWell(
                          onTap: () async {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (photo != null) {
                              final bytes = await photo.readAsBytes();
                              setSheet(() {
                                evidenceBytes = bytes;
                                evidenceName = photo.name;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: line),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  evidenceBytes != null
                                      ? Icons.check_circle_rounded
                                      : Icons.photo_camera_outlined,
                                  color: evidenceBytes != null ? forest : muted,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    evidenceBytes != null
                                        ? 'Foto bukti terlampir (${evidenceName ?? 'foto.jpg'})'
                                        : 'Unggah foto bukti / kondisi (opsional)',
                                    style: TextStyle(
                                      color: evidenceBytes != null ? ink : muted,
                                      fontSize: 12,
                                      fontWeight: evidenceBytes != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final notes = detailsController.text.trim();
                                        if (notes.isEmpty) {
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Detail kejadian wajib diisi.')));
                                          return;
                                        }

                                        setSheet(() => isSubmitting = true);

                                        try {
                                          await ApiService.createReport(
                                            kgItemId: selectedItem?.id,
                                            kind: kind,
                                            notes: notes,
                                            evidenceBytes: evidenceBytes,
                                            evidenceFileName: evidenceName,
                                          );

                                          if (!sheetContext.mounted) return;
                                          Navigator.pop(sheetContext);

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Laporan kejadian berhasil dikirim.'),
                                                  backgroundColor: forest,
                                                  behavior: SnackBarBehavior
                                                      .floating));

                                          _loadData();
                                        } catch (e) {
                                          if (!sheetContext.mounted) return;
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(SnackBar(
                                            content: Text(e
                                                .toString()
                                                .replaceAll('Exception: ', '')),
                                            backgroundColor:
                                                Colors.red.shade700,
                                          ));
                                          setSheet(() => isSubmitting = false);
                                        }
                                      },
                                style: FilledButton.styleFrom(
                                    backgroundColor: forest,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Kirim laporan',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)))),
                      ]),
                ),
              )),
    ).whenComplete(detailsController.dispose);
  }
}
