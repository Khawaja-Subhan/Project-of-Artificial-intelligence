import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/route_model.dart';
import '../../models/user_model.dart';
import '../../state/app_state.dart';
import '../reader/meter_detector_test_screen.dart';

/// System settings and threshold tuning screen (FR-28, FR-55 to FR-58).
class AdminSettingsScreen extends StatefulWidget {
  final AppState state;

  const AdminSettingsScreen({
    super.key,
    required this.state,
  });

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late double _greenConf;
  late double _amberConf;
  late double _maxMultiplier;
  late String _activeModel;

  @override
  void initState() {
    super.initState();
    _greenConf = widget.state.ruleEngine.greenConfidenceThreshold;
    _amberConf = widget.state.ruleEngine.amberConfidenceThreshold;
    _maxMultiplier = widget.state.ruleEngine.maxConsumptionMultiplier;
    _activeModel = widget.state.aiService.activeModelVersion;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppStrings.settingsTab),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Role & Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.state.currentUser.name,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            widget.state.currentUser.roleDisplayName,
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Switch Active Role dropdown
                DropdownButtonFormField<UserRole>(
                  value: widget.state.currentUser.role,
                  decoration: const InputDecoration(labelText: 'Switch Active Role Profile'),
                  items: const [
                    DropdownMenuItem(value: UserRole.reader, child: Text('Meter Reader (Field Mode)')),
                    DropdownMenuItem(value: UserRole.supervisor, child: Text('Supervisor / Verifier (Queue)')),
                    DropdownMenuItem(value: UserRole.admin, child: Text('MMR Administrator / AI Ops')),
                  ],
                  onChanged: (role) {
                    if (role != null) widget.state.switchRole(role);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Route Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISCO Subdivision & Route (FR-4)',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<RouteModel>(
                  value: widget.state.activeRoute,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Current Assigned Route'),
                  items: widget.state.db.routes.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text('${r.discoCode} • ${r.name}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (r) {
                    if (r != null) widget.state.setActiveRoute(r);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tunable Validation Thresholds (FR-28, FR-56)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Validation Thresholds (FR-28)',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust thresholds in real time without rebuilding the application.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 16),

                // Green Confidence Slider
                Text(
                  'Green Confidence Threshold: ${(_greenConf * 100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _greenConf,
                  min: 0.80,
                  max: 0.98,
                  divisions: 18,
                  label: '${(_greenConf * 100).toInt()}%',
                  activeColor: AppColors.statusGreen,
                  onChanged: (val) {
                    setState(() => _greenConf = val);
                    widget.state.ruleEngine.greenConfidenceThreshold = val;
                  },
                ),

                // Amber Confidence Slider
                Text(
                  'Amber Confidence Threshold: ${(_amberConf * 100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _amberConf,
                  min: 0.50,
                  max: 0.85,
                  divisions: 35,
                  label: '${(_amberConf * 100).toInt()}%',
                  activeColor: AppColors.statusAmber,
                  onChanged: (val) {
                    setState(() => _amberConf = val);
                    widget.state.ruleEngine.amberConfidenceThreshold = val;
                  },
                ),

                // Consumption Multiplier Slider
                Text(
                  'Max Consumption Spike Multiplier: ${_maxMultiplier.toStringAsFixed(1)}x Average',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _maxMultiplier,
                  min: 2.0,
                  max: 5.0,
                  divisions: 30,
                  label: '${_maxMultiplier.toStringAsFixed(1)}x',
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _maxMultiplier = val);
                    widget.state.ruleEngine.maxConsumptionMultiplier = val;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Swappable Model Version (FR-25, FR-57, FR-61)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'AI Inference Model Engine (FR-61)',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _activeModel,
                  decoration: const InputDecoration(labelText: 'Active Optical Model'),
                  items: const [
                    DropdownMenuItem(
                      value: AppConstants.currentModelVersion,
                      child: Text('detector-v0.3 / ocr-v0.2 (Quantized INT8)'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.baselineModelVersion,
                      child: Text('detector-v0.1 / ocr-baseline (FP16 Baseline)'),
                    ),
                  ],
                  onChanged: (model) {
                    if (model != null) {
                      setState(() => _activeModel = model);
                      widget.state.aiService.setModelVersion(model);
                    }
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.document_scanner_rounded, size: 18, color: Color(0xFF38BDF8)),
                    label: Text(
                      'Launch YOLO11n-OBB Detector Test Screen',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MeterDetectorTestScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Connectivity & Language
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                // Network Mode Simulation Switch (FR-34)
                SwitchListTile(
                  title: Text(
                    'Online Cloud Connection Mode',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    widget.state.syncService.isOnline
                        ? 'Simulating Active Cellular / Wi-Fi Sync'
                        : 'Simulating 100% Offline Field Mode',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  value: widget.state.syncService.isOnline,
                  activeColor: AppColors.primary,
                  onChanged: (_) => widget.state.toggleOnlineMode(),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Language Toggle (FR-58)
                ListTile(
                  title: Text(
                    'Language / زبان (FR-58)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    widget.state.isUrdu ? 'اردو (Urdu UI Active)' : 'English (Default)',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  trailing: OutlinedButton(
                    onPressed: widget.state.toggleLanguage,
                    child: Text(widget.state.isUrdu ? 'Switch to English' : 'اردو کریں'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reset Demo Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.statusRed,
              side: const BorderSide(color: AppColors.statusRed),
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('Reset All Local Demo Data to Seed Default'),
            onPressed: () async {
              await widget.state.resetDemoData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Demo dataset refreshed to initial 75 consumers and meters.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
