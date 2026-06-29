import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/admin_event.dart';
import '../../domain/entities/admin_announcement.dart';
import '../providers/admin_provider.dart';
import '../../../sos/domain/entities/emergency_alert.dart';
import '../../../sos/presentation/providers/sos_provider.dart';
import '../../../map/presentation/widgets/campus_map_view.dart';
import '../../../map/domain/entities/geo_point.dart';
import '../../../notifications/domain/entities/notification_item.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../map/presentation/providers/map_providers.dart';
import '../../../sos/domain/failures/sos_failure.dart';
import '../../../../core/providers/core_providers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const AdminDashboardScreen({this.initialTab = 0, super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void didUpdateWidget(covariant AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminDashboardProvider);
    final activeAlertsAsync = ref.watch(activeAlertsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: const Color(0xFF1E1E1E),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFC2185B),
            labelColor: const Color(0xFFC2185B),
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Users'),
              Tab(text: 'Events'),
              Tab(text: 'Alerts Monitor'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(adminState: adminState),
          _UsersTab(adminState: adminState),
          _EventsTab(adminState: adminState),
          _AlertsMonitorTab(activeAlertsAsync: activeAlertsAsync),
        ],
      ),
    );
  }
}

// ── Tab 0: Overview & Announcements ──────────────────────────────────────────
class _OverviewTab extends ConsumerStatefulWidget {
  final AdminDashboardState adminState;
  const _OverviewTab({required this.adminState});

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPublishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _publishAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isPublishing = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    final success = await ref.read(adminDashboardProvider.notifier).createAnnouncement(
      title: title,
      content: content,
    );

    if (success) {
      // Add announcement notification trigger
      final notifyItem = NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: content,
        type: NotificationType.announcement,
        createdAt: DateTime.now(),
        isRead: false,
      );
      await ref.read(notificationActionProvider.notifier).addNotification(notifyItem);

      _titleController.clear();
      _contentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement dispatched & notifications broadcasted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to publish announcement.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isPublishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers = widget.adminState.users.length;
    final totalEvents = widget.adminState.events.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Row
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Total Users',
                  value: '$totalUsers',
                  icon: Icons.people,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Campus Events',
                  value: '$totalEvents',
                  icon: Icons.event,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dispatch announcement Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white12),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DISPATCH CAMPUS ANNOUNCEMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Announcement Title',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Write announcement details here...',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Content details are required' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isPublishing ? null : _publishAnnouncement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC2185B),
                        foregroundColor: Colors.white,
                      ),
                      child: _isPublishing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Publish Announcement'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'RECENT ANNOUNCEMENTS',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          if (widget.adminState.announcements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text('No announcements dispatched yet.', style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.adminState.announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ann = widget.adminState.announcements[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ann.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ann.content,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Published on: ${ann.timestamp.toLocal().toString().substring(0, 16)}',
                        style: const TextStyle(color: Colors.white30, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Tab 1: Users Role Management ─────────────────────────────────────────────
class _UsersTab extends ConsumerWidget {
  final AdminDashboardState adminState;
  const _UsersTab({required this.adminState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (adminState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: adminState.users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = adminState.users[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: user.isAdmin ? const Color(0xFFC2185B) : Colors.grey.shade800,
                child: Icon(
                  user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: user.isAdmin ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.blue.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: user.isAdmin ? Colors.red.shade800 : Colors.blue.shade800,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        color: user.isAdmin ? Colors.red.shade300 : Colors.blue.shade300,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () async {
                      final targetRole = user.isAdmin ? 'student' : 'admin';
                      final success = await ref.read(adminDashboardProvider.notifier).updateUserRole(user.id, targetRole);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${user.name} is now a $targetRole.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      user.isAdmin ? 'Demote' : 'Make Admin',
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab 2: Events Management ─────────────────────────────────────────
class _EventsTab extends ConsumerStatefulWidget {
  final AdminDashboardState adminState;
  const _EventsTab({required this.adminState});

  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _venueController = TextEditingController();
  DateTime? _selectedDate;
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    
    if (mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );
      if (time == null) return;

      setState(() {
        _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      });
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date & time.')),
      );
      return;
    }

    setState(() => _isCreating = true);
    final success = await ref.read(adminDashboardProvider.notifier).createEvent(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      venue: _venueController.text.trim(),
      timestamp: _selectedDate!,
    );

    if (success) {
      _titleController.clear();
      _descController.clear();
      _venueController.clear();
      setState(() {
        _selectedDate = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campus Event created successfully.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create event.')),
        );
      }
    }
    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white12),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CREATE CAMPUS EVENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Event Title',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Event Description',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _venueController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Venue (e.g. Faculty of Science Lab)',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Venue is required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null
                            ? 'No Date/Time selected'
                            : 'Selected: ${_selectedDate!.toLocal().toString().substring(0, 16)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      TextButton.icon(
                        onPressed: _pickDateTime,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Pick Date/Time'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC2185B),
                        foregroundColor: Colors.white,
                      ),
                      child: _isCreating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Publish Event'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'UPCOMING CAMPUS EVENTS',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          if (widget.adminState.events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text('No upcoming events listed.', style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.adminState.events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ev = widget.adminState.events[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ev.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(ev.venue, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time_outlined, color: Colors.blueAccent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                ev.timestamp.toLocal().toString().substring(0, 16),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Tab 3: Alerts Monitor Map & Lists ────────────────────────────────────────
class _AlertsMonitorTab extends ConsumerStatefulWidget {
  final AsyncValue<List<EmergencyAlert>> activeAlertsAsync;
  const _AlertsMonitorTab({required this.activeAlertsAsync});

  @override
  ConsumerState<_AlertsMonitorTab> createState() => _AlertsMonitorTabState();
}

class _AlertsMonitorTabState extends ConsumerState<_AlertsMonitorTab> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buildingsAsync = ref.watch(buildingsProvider);

    return widget.activeAlertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading alerts: $err', style: const TextStyle(color: Colors.red))),
      data: (alerts) {
        return Column(
          children: [
            // Map Monitor takes up half screen
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  CampusMapView(
                    mapController: _mapController,
                    buildings: buildingsAsync.maybeWhen(
                      data: (list) => list,
                      orElse: () => const [],
                    ),
                    extraMarkers: alerts.map((a) {
                      return Marker(
                        point: ll.LatLng(a.location.latitude, a.location.longitude),
                        width: 60,
                        height: 60,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 20 + (_pulseController.value * 30),
                                  height: 20 + (_pulseController.value * 30),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withValues(alpha: 1.0 - _pulseController.value),
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                                    ],
                                  ),
                                  child: const Icon(Icons.warning, color: Colors.white, size: 12),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade800),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.radio_button_checked, color: Colors.red, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${alerts.length} ACTIVE EMERGENCY SIGNAL(S)',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Active list and resolution triggers
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF161616),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: alerts.isEmpty
                    ? const Center(
                        child: Text(
                          'System normal. No active SOS alerts.',
                          style: TextStyle(color: Colors.white30, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert.senderName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Coords: ${alert.location.latitude.toStringAsFixed(5)}, ${alert.location.longitude.toStringAsFixed(5)}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace'),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Triggered: ${alert.timestamp.toLocal().toString().substring(11, 16)} (${DateTime.now().difference(alert.timestamp).inMinutes}m ago)',
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final sosRepo = ref.read(sosRepositoryProvider);
                                    final res = await sosRepo.resolveAlert(alert.id);
                                    if (res is SosSuccess<void> && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Emergency alert for ${alert.senderName} resolved.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: const Size(60, 30),
                                  ),
                                  child: const Text('Resolve', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Helper Metric Card Widget
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              textStyle: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
