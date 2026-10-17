import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/consumer_model.dart';
import '../../models/reading_model.dart';
import '../../models/validation_result.dart';
import '../../state/app_state.dart';
import 'camera_capture_screen.dart';

/// Meter Reader's primary workspace showing assigned route and consumers (FR-5, FR-6, FR-7, FR-8).
class RouteConsumerListScreen extends StatelessWidget {
  final AppState state;

  const RouteConsumerListScreen({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final route = state.activeRoute;
    final filtered = state.filteredConsumers;
    final total = state.routeTotalCount;
    final done = state.routeCompletedCount;
    final progressPct = total > 0 ? (done / total) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // App Bar with Route Header
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'BATCH ${route?.batchNo ?? '04'}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          route?.subdivision ?? 'Gulberg Sub-Division',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      route?.name ?? 'Assigned Meter Route',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Offline Download / Route Sync Button (FR-7)
              IconButton(
                tooltip: 'Sync Route Data',
                icon: Icon(
                  state.syncService.isSyncing
                      ? Icons.sync_rounded
                      : Icons.cloud_download_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  state.triggerSync();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Route data synced for offline operation (FR-7).'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),

          // Progress & Stats Header (FR-8: "42 of 120 done")
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Route Progress: $done of $total done',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '${(progressPct * 100).toInt()}% Completed',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressPct,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Box (FR-6)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                onChanged: state.setSearchQuery,
                decoration: InputDecoration(
                  hintText: AppStrings.searchPlaceholder,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
          ),

          // Status Filter Tabs (FR-6: Filter by status)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: ['All', 'Pending', 'Done', 'Flagged', 'Problem'].map((status) {
                  final isSelected = state.consumerStatusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.borderLight,
                        ),
                      ),
                      onSelected: (_) => state.setStatusFilter(status),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Consumer List Items
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      'No consumers match the filter.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final consumer = filtered[index];
                    final meter = state.db.getMeterById(consumer.meterId);
                    final reading = state.db.getReadingForConsumer(consumer.id);

                    return _ConsumerCard(
                      consumer: consumer,
                      meterId: meter?.meterNo ?? consumer.meterId,
                      meterType: meter?.typeLabel ?? 'Single Phase Digital LCD',
                      reading: reading,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CameraCaptureScreen(
                              state: state,
                              consumer: consumer,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsumerCard extends StatelessWidget {
  final ConsumerModel consumer;
  final String meterId;
  final String meterType;
  final ReadingModel? reading;
  final VoidCallback onTap;

  const _ConsumerCard({
    required this.consumer,
    required this.meterId,
    required this.meterType,
    required this.reading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = const Color(0xFF64748B);
    Color statusBg = const Color(0xFFF1F5F9);
    String statusText = 'PENDING';
    IconData statusIcon = Icons.hourglass_top_rounded;

    if (reading != null) {
      if (reading!.status == ReadingStatus.problem) {
        statusColor = AppColors.statusRed;
        statusBg = AppColors.statusRedBg;
        statusText = 'PROBLEM';
        statusIcon = Icons.report_problem_rounded;
      } else if (reading!.trafficLight == TrafficLight.green) {
        statusColor = AppColors.statusGreen;
        statusBg = AppColors.statusGreenBg;
        statusText = 'DONE (GREEN)';
        statusIcon = Icons.check_circle_rounded;
      } else if (reading!.trafficLight == TrafficLight.amber) {
        statusColor = AppColors.statusAmber;
        statusBg = AppColors.statusAmberBg;
        statusText = 'FLAGGED (AMBER)';
        statusIcon = Icons.warning_rounded;
      } else {
        statusColor = AppColors.statusRed;
        statusBg = AppColors.statusRedBg;
        statusText = 'FLAGGED (RED)';
        statusIcon = Icons.cancel_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: reading != null ? statusColor.withOpacity(0.3) : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference Number & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        consumer.referenceNo,
                        style: GoogleFonts.chivoMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Consumer Name & Tariff
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        consumer.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: consumer.tariffCategory == 'Commercial'
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        consumer.tariffCategory.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: consumer.tariffCategory == 'Commercial'
                              ? const Color(0xFF0369A1)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Address
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        consumer.address,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 18),

                // Meter Specs & Previous Reading
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'METER: $meterId',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          meterType,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PREV: ${consumer.previousReading.toStringAsFixed(1)} kWh',
                          style: GoogleFonts.chivoMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        if (reading != null)
                          Text(
                            'NEW: ${reading!.finalValue.toStringAsFixed(1)} kWh',
                            style: GoogleFonts.chivoMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          )
                        else
                          Text(
                            'Tap to Photograph',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
