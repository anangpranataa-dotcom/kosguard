import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final KGUser currentUser;

  const OwnerDashboardScreen({super.key, required this.currentUser});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedSection = 0; // 0: Klaim Masuk, 1: Kelola Insiden, 2: Inventaris
  bool _isLoading = true;
  String? _errorMessage;

  DashboardSummary _summary = const DashboardSummary();
  List<KGClaim> _claims = [];
  List<KGReport> _reports = [];
  List<KGItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil Summary Statistik
      final summaryRes = await ApiService.getDashboardSummary();
      final summaryData = summaryRes['data'] is Map<String, dynamic>
          ? summaryRes['data'] as Map<String, dynamic>
          : summaryRes;
      final summary = DashboardSummary.fromJson(summaryData);

      // 2. Ambil Klaim Masuk
      final rawClaims = await ApiService.getClaims();
      final claims = rawClaims
          .whereType<Map<String, dynamic>>()
          .map((c) => KGClaim.fromJson(c))
          .toList();

      // 3. Ambil Laporan Insiden
      final rawReports = await ApiService.getReports();
      final reports = rawReports
          .whereType<Map<String, dynamic>>()
          .map((r) => KGReport.fromJson(r))
          .toList();

      // 4. Ambil Items Inventaris
      final rawItems = await ApiService.getItems();
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => KGItem.fromJson(i))
          .toList();

      if (mounted) {
        setState(() {
          _summary = summary;
          _claims = claims;
          _reports = reports;
          _items = items;
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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Keluar dari Dashboard?',
            style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
        content: const Text('Anda akan keluar dari sesi pengelola kos.',
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

  void _reviewClaimModal(KGClaim claim) {
    final notesController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          16,
          22,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
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
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Verifikasi Klaim Kepemilikan',
                style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Pengaju: ${claim.claimantName} · Kamar ${claim.claimantRoom}',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DETAIL RAHASIA PENGAKUAN:',
                        style: TextStyle(
                            color: leaf, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Text(
                      claim.privateDetails.isNotEmpty ? claim.privateDetails : '(Tidak ada detail tertulis)',
                      style: const TextStyle(color: ink, fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Catatan Resolusi (Opsional)',
                  hintText: 'Misal: Bukti cocok dengan laporan penemu.',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: line),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _submitClaimReview(
                          claim.id,
                          'REJECTED',
                          notesController.text.trim(),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Tolak Klaim', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _submitClaimReview(
                          claim.id,
                          'APPROVED',
                          notesController.text.trim(),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: forest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Setujui Klaim', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(notesController.dispose);
  }

  Future<void> _submitClaimReview(int claimId, String action, String notes) async {
    try {
      await ApiService.reviewClaim(
        claimId,
        action: action,
        resolutionNotes: notes.isNotEmpty ? notes : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'APPROVED' ? 'Klaim berhasil disetujui.' : 'Klaim telah ditolak.',
          ),
          backgroundColor: action == 'APPROVED' ? forest : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateReportStatusModal(KGReport report) {
    String selectedStatus = report.status;
    final notesController = TextEditingController(text: report.handlingNotes ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
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
                  'Perbarui Status Insiden',
                  style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Laporan: ${report.kindLabel} · Pelapor: ${report.reporterName} (Kmr ${report.roomNumber})',
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                const Text('Pilih Status:',
                    style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in ['OPEN', 'UNDER_REVIEW', 'RESOLVED'])
                      ChoiceChip(
                        label: Text(s == 'OPEN'
                            ? 'Buka (OPEN)'
                            : s == 'UNDER_REVIEW'
                                ? 'Sedang Ditinjau'
                                : 'Selesai (RESOLVED)'),
                        selected: selectedStatus == s,
                        onSelected: (_) => setSheet(() => selectedStatus = s),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: selectedStatus == s ? Colors.white : ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: forest,
                        side: BorderSide(color: selectedStatus == s ? forest : line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan Penanganan',
                    hintText: 'Misal: Telah diverifikasi dan diserahkan ke pemilik.',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: line),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      try {
                        await ApiService.updateReportStatus(
                          report.id,
                          status: selectedStatus,
                          notes: notesController.text.trim(),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Status insiden berhasil diperbarui.'),
                            backgroundColor: forest,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _loadDashboardData();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: forest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Simpan Perubahan',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(notesController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: forest,
          backgroundColor: Colors.white,
          onRefresh: _loadDashboardData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              // Greeting
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.admin_panel_settings_rounded, size: 16, color: leaf),
                          const SizedBox(width: 5),
                          Text(
                            'PENGELOLA PROPERTI · ${widget.currentUser.propertyName.toUpperCase()}',
                            style: const TextStyle(
                              color: leaf,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ringkasan Operasional',
                        style: TextStyle(
                          color: ink,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 4 Stat Summary Cards
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                sliver: SliverToBoxAdapter(child: _buildStatGrid()),
              ),
              // Navigation Tabs
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                sliver: SliverToBoxAdapter(child: _buildSectionSelector()),
              ),
              // Dynamic Content Section
              if (_isLoading && _claims.isEmpty && _reports.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: forest, strokeWidth: 2)),
                )
              else if (_errorMessage != null && _claims.isEmpty && _reports.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(_errorMessage!, style: const TextStyle(color: muted, fontSize: 13)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                  sliver: _buildSelectedSectionSliver(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E0D8)),
          ),
          child: Image.asset(
            'assets/images/icon.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'kosguard owner',
                style: TextStyle(
                  color: ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                'Halo, ${widget.currentUser.name}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Keluar',
          icon: const Icon(Icons.logout_rounded, color: ink),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildStatGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _statCard(
          title: 'Barang Aktif',
          value: '${_summary.activeItemsCount}',
          icon: Icons.inventory_2_outlined,
          color: forest,
          bgColor: const Color(0xFFEAF1E9),
        ),
        _statCard(
          title: 'Kedaluwarsa',
          value: '${_summary.expiredCount}',
          icon: Icons.schedule_rounded,
          color: const Color(0xFFA86C2C),
          bgColor: const Color(0xFFFFF4E5),
        ),
        _statCard(
          title: 'Insiden Terbuka',
          value: '${_summary.openIncidentsCount}',
          icon: Icons.report_problem_outlined,
          color: const Color(0xFFC53030),
          bgColor: const Color(0xFFFDE8E8),
        ),
        _statCard(
          title: 'Klaim Tertunda',
          value: '${_summary.pendingClaimsCount}',
          icon: Icons.assignment_outlined,
          color: amber,
          bgColor: const Color(0xFFFEF3C7),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: color),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    final pendingCount = _claims.where((c) => c.isPending).length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBE9E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _sectionButton(
              title: pendingCount > 0 ? 'Klaim ($pendingCount)' : 'Klaim',
              index: 0,
            ),
          ),
          Expanded(
            child: _sectionButton(
              title: 'Insiden (${_reports.length})',
              index: 1,
            ),
          ),
          Expanded(
            child: _sectionButton(
              title: 'Inventaris (${_items.length})',
              index: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionButton({required String title, required int index}) {
    final isSelected = _selectedSection == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? line : Colors.transparent),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? ink : muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSectionSliver() {
    switch (_selectedSection) {
      case 0:
        return _buildClaimsListSliver();
      case 1:
        return _buildReportsListSliver();
      case 2:
      default:
        return _buildItemsListSliver();
    }
  }

  Widget _buildClaimsListSliver() {
    if (_claims.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: const Center(
            child: Text(
              'Belum ada klaim kepemilikan yang masuk.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: _claims.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final claim = _claims[index];
        final isPending = claim.isPending;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFEAF1E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      claim.status,
                      style: TextStyle(
                        color: isPending ? const Color(0xFFA86C2C) : forest,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Klaim #${claim.id}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Pengaju: ${claim.claimantName} · Kamar ${claim.claimantRoom}',
                style: const TextStyle(color: ink, fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DETAIL RAHASIA PENGAKUAN:',
                        style: TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      claim.privateDetails.isNotEmpty
                          ? claim.privateDetails
                          : '(Tidak ada catatan tertulis)',
                      style: const TextStyle(color: Color(0xFF3E4A43), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (claim.resolutionNotes != null && claim.resolutionNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Catatan verifikasi: ${claim.resolutionNotes}',
                  style: const TextStyle(color: muted, fontSize: 11.5, fontStyle: FontStyle.italic),
                ),
              ],
              if (isPending) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: () => _reviewClaimModal(claim),
                    style: FilledButton.styleFrom(
                      backgroundColor: forest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    icon: const Icon(Icons.rule_folder_outlined, size: 17),
                    label: const Text('Verifikasi Klaim',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsListSliver() {
    if (_reports.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: const Center(
            child: Text(
              'Tidak ada laporan insiden saat ini.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = _reports[index];
        final isOpen = report.isOpen;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFFFDE8E8) : const Color(0xFFEAF1E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      report.kindLabel.toUpperCase(),
                      style: TextStyle(
                        color: isOpen ? const Color(0xFFC53030) : leaf,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFFFFF4E5) : const Color(0xFFECEFE7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      report.status,
                      style: TextStyle(
                        color: isOpen ? amber : forest,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (report.itemName != null) ...[
                Text(
                  report.itemName!,
                  style: const TextStyle(color: ink, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                report.notes,
                style: const TextStyle(color: Color(0xFF425048), fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    '${report.reporterName} (Kamar ${report.roomNumber})',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  const Spacer(),
                  Text(
                    '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                    style: const TextStyle(color: muted, fontSize: 10.5),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () => _updateReportStatusModal(report),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: forest,
                    side: const BorderSide(color: forest),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Ubah Status & Catatan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsListSliver() {
    if (_items.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: const Center(
            child: Text(
              'Belum ada barang di ruang bersama.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final isActive = item.status == ItemStatus.active;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.artBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.artColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(color: ink, fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.facility} · Kamar ${item.room} · ${item.remaining}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFEAF1E9) : const Color(0xFFECECE6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.rawStatus,
                  style: TextStyle(
                    color: isActive ? leaf : muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
