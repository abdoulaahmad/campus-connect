import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../providers/schedule_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _selectedDay = 'monday';
  bool? _paintValue; // true to paint 1s, false to paint 0s

  final List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  String _formatTime(int index) {
    final startHour = index ~/ 2;
    final startMin = (index % 2) * 30;
    final endIndex = index + 1;
    final endHour = endIndex ~/ 2;
    final endMin = (endIndex % 2) * 30;

    final startStr = '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')}';
    final endStr = '${endHour == 24 ? "00" : endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
    return '$startStr-$endStr';
  }

  void _processTouch(Offset localPos, double width, double height, ScheduleEditNotifier notifier, String mask) {
    final cellWidth = width / 4;
    final cellHeight = height / 12;

    int col = (localPos.dx / cellWidth).floor();
    int row = (localPos.dy / cellHeight).floor();

    if (col >= 0 && col < 4 && row >= 0 && row < 12) {
      final index = row * 4 + col;
      if (_paintValue == null) {
        // First touch: determine if we are painting '1's or '0's
        final currentVal = mask.length > index ? mask[index] == '1' : false;
        _paintValue = !currentVal;
      }
      notifier.setSlot(_selectedDay, index, _paintValue!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final userId = user?.id ?? 'u1';
    final editState = ref.watch(scheduleEditProvider(userId));
    final editNotifier = ref.read(scheduleEditProvider(userId).notifier);

    final String activeMask = editState.dailyBitmasks[_selectedDay] ?? '0' * 48;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('My Profile & Availability'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          if (editState.isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save, color: Color(0xFFC2185B)),
              onPressed: () async {
                final success = await editNotifier.save();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Availability schedule saved successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: editState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFFC2185B).withValues(alpha: 0.2),
                          child: const Icon(Icons.person, size: 36, color: Color(0xFFC2185B)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Abdullahi Abba Ahmad',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? 'abdullahi@fud.edu.ng',
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Role: ${user?.role.toUpperCase()}',
                                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'WEEKLY AVAILABILITY GRID',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap single blocks or drag finger to paint blocks of availability.',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Day Select chip horizontal scroll
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _days.map((day) {
                        final isSelected = _selectedDay == day;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(day[0].toUpperCase() + day.substring(1)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedDay = day;
                                });
                              }
                            },
                            selectedColor: const Color(0xFFC2185B).withValues(alpha: 0.3),
                            backgroundColor: const Color(0xFF1E1E1E),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFFC2185B) : Colors.white70,
                            ),
                            checkmarkColor: const Color(0xFFC2185B),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // The Interactive 12x4 grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final gridWidth = constraints.maxWidth;
                      const gridHeight = 480.0; // Fixed height for 12 rows

                      return GestureDetector(
                        onPanStart: (details) {
                          _paintValue = null;
                          _processTouch(details.localPosition, gridWidth, gridHeight, editNotifier, activeMask);
                        },
                        onPanUpdate: (details) {
                          _processTouch(details.localPosition, gridWidth, gridHeight, editNotifier, activeMask);
                        },
                        onPanEnd: (_) {
                          _paintValue = null;
                        },
                        onTapDown: (details) {
                          _paintValue = null;
                          _processTouch(details.localPosition, gridWidth, gridHeight, editNotifier, activeMask);
                        },
                        child: Container(
                          width: gridWidth,
                          height: gridHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              children: List.generate(12, (rowIndex) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(4, (colIndex) {
                                      final index = rowIndex * 4 + colIndex;
                                      final isActive = activeMask.length > index && activeMask[index] == '1';
                                      
                                      return Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? const Color(0xFFC2185B).withValues(alpha: 0.75)
                                                : const Color(0xFF181818),
                                            border: Border.all(color: Colors.white12, width: 0.5),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _formatTime(index),
                                            style: TextStyle(
                                              color: isActive ? Colors.white : Colors.white38,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Reset availability button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        for (int i = 0; i < 48; i++) {
                          editNotifier.setSlot(_selectedDay, i, false);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: const Text('Clear Day Availability'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
