import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<KGNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final rawList = await ApiService.getNotifications();
      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((n) => KGNotification.fromJson(n))
          .toList();

      if (mounted) {
        setState(() {
          _notifications = list;
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

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map((n) => KGNotification(
                    id: n.id,
                    title: n.title,
                    body: n.body,
                    isRead: true,
                    type: n.type,
                    data: n.data,
                    createdAt: n.createdAt,
                  ))
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua notifikasi ditandai sudah dibaca.'),
            backgroundColor: forest,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  IconData _getNotificationIcon(String? type, String title) {
    final t = (type ?? '').toLowerCase();
    final lowerTitle = title.toLowerCase();

    if (t.contains('expired') || lowerTitle.contains('berakhir') || lowerTitle.contains('habis')) {
      return Icons.schedule_rounded;
    }
    if (t.contains('incident') || lowerTitle.contains('laporan') || lowerTitle.contains('hilang')) {
      return Icons.report_problem_rounded;
    }
    if (t.contains('claim') || lowerTitle.contains('klaim')) {
      return Icons.assignment_turned_in_rounded;
    }
    return Icons.notifications_none_rounded;
  }

  Color _getIconColor(String? type, String title) {
    final t = (type ?? '').toLowerCase();
    final lowerTitle = title.toLowerCase();

    if (t.contains('expired') || lowerTitle.contains('berakhir') || lowerTitle.contains('habis')) {
      return amber;
    }
    if (t.contains('incident') || lowerTitle.contains('laporan') || lowerTitle.contains('hilang')) {
      return const Color(0xFFC05621);
    }
    if (t.contains('claim') || lowerTitle.contains('klaim')) {
      return leaf;
    }
    return forest;
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} mnt lalu';
    if (diff.inDays == 0) return 'Hari ini · $clock';
    if (diff.inDays == 1) return 'Kemarin · $clock';
    return '${time.day}/${time.month}/${time.year} · $clock';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(
                color: ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount baru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tandai dibaca',
                style: TextStyle(
                  color: forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: forest,
          backgroundColor: Colors.white,
          onRefresh: _fetchNotifications,
          child: _isLoading && _notifications.isEmpty
              ? const Center(child: CircularProgressIndicator(color: forest, strokeWidth: 2))
              : _errorMessage != null && _notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 40, color: amber),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: muted, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _fetchNotifications,
                              style: FilledButton.styleFrom(backgroundColor: forest),
                              child: const Text('Coba Lagi'),
                            )
                          ],
                        ),
                      ),
                    )
                  : _notifications.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFECEFE7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.notifications_none_rounded,
                                        color: leaf, size: 26),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text('Belum ada notifikasi',
                                      style: TextStyle(
                                          color: ink, fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Pemberitahuan durasi fasilitas dan status insiden akan muncul di sini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: muted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _notifications[index];
                            final iconColor = _getIconColor(item.type, item.title);
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: item.isRead ? Colors.white : const Color(0xFFFBFBF8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: item.isRead ? line : forest.withValues(alpha: 0.3),
                                  width: item.isRead ? 1 : 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(item.type, item.title),
                                      size: 18,
                                      color: iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  color: ink,
                                                  fontSize: 13.5,
                                                  fontWeight: item.isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (!item.isRead) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: amber,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.body,
                                          style: TextStyle(
                                            color: item.isRead
                                                ? muted
                                                : const Color(0xFF3B4842),
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatTime(item.createdAt),
                                          style: const TextStyle(color: muted, fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
