import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../state/app_state.dart';
import '../dashboard/metrics_dashboard_screen.dart';
import '../reader/route_consumer_list_screen.dart';
import '../settings/admin_settings_screen.dart';
import '../supervisor/supervisor_queue_screen.dart';

/// Main navigation shell housing role-aware tabs, quick switcher banner, and status bars.
class MainShell extends StatefulWidget {
  final AppState state;

  const MainShell({
    super.key,
    required this.state,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final user = state.currentUser;
    final isOnline = state.syncService.isOnline;
    final queueCount = state.supervisorQueue.length;

    final screens = [
      RouteConsumerListScreen(state: state),
      SupervisorQueueScreen(state: state),
      MetricsDashboardScreen(state: state),
      AdminSettingsScreen(state: state),
    ];

    return Scaffold(
      body: Column(
        children: [
          // Top Quick-Role Switcher & Connectivity Status Banner
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Dark slate
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  // Role Badge & Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.role == UserRole.reader
                          ? const Color(0xFF0284C7)
                          : user.role == UserRole.supervisor
                              ? const Color(0xFF059669)
                              : const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user.role == UserRole.reader
                          ? 'READER MODE'
                          : user.role == UserRole.supervisor
                              ? 'SUPERVISOR MODE'
                              : 'ADMIN / AI OPS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      user.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Quick Switch Role Icon Menu
                  PopupMenuButton<UserRole>(
                    tooltip: 'Switch Active Role Profile',
                    icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 20),
                    onSelected: (role) {
                      state.switchRole(role);
                      if (role == UserRole.supervisor) {
                        setState(() => _currentIndex = 1);
                      } else if (role == UserRole.admin) {
                        setState(() => _currentIndex = 2);
                      } else {
                        setState(() => _currentIndex = 0);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: UserRole.reader, child: Text('Switch to Meter Reader')),
                      const PopupMenuItem(value: UserRole.supervisor, child: Text('Switch to Supervisor')),
                      const PopupMenuItem(value: UserRole.admin, child: Text('Switch to Admin / AI Ops')),
                    ],
                  ),

                  // Network Connectivity Pill (FR-34)
                  InkWell(
                    onTap: state.toggleOnlineMode,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF064E3B) : const Color(0xFF451A03),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            size: 11,
                            color: isOnline ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'ONLINE' : 'OFFLINE',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isOnline ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Language Toggle
                  InkWell(
                    onTap: state.toggleLanguage,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        state.isUrdu ? 'EN' : 'اردو',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Active View
          Expanded(child: screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppColors.primary.withOpacity(0.12),
        backgroundColor: Colors.white,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route_rounded, color: AppColors.primary),
            label: AppStrings.routeTab,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: queueCount > 0,
              label: Text('$queueCount'),
              backgroundColor: AppColors.statusAmber,
              child: const Icon(Icons.rule_folder_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: queueCount > 0,
              label: Text('$queueCount'),
              backgroundColor: AppColors.statusAmber,
              child: const Icon(Icons.rule_folder_rounded, color: AppColors.primary),
            ),
            label: AppStrings.queueTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded, color: AppColors.primary),
            label: AppStrings.dashboardTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune_rounded, color: AppColors.primary),
            label: AppStrings.settingsTab,
          ),
        ],
      ),
    );
  }
}
