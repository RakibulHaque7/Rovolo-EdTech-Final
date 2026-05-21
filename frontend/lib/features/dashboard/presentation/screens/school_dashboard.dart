import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../attendance/data/attendance_repository.dart';

class SchoolDashboard extends StatefulWidget {
  final Map<String, dynamic> profile;

  const SchoolDashboard({super.key, required this.profile});

  @override
  State<SchoolDashboard> createState() => _SchoolDashboardState();
}

class _SchoolDashboardState extends State<SchoolDashboard> {
  String _activeTab = 'dashboard';
  final AuthRepository _authRepo = AuthRepository();
  final AttendanceRepository _attendanceRepo = AttendanceRepository();

  // State Variables
  bool _isLoading = true;
  bool _isActionLoading = false;
  Map<String, dynamic>? _dashboardData;
  String _errorMessage = '';

  // Geofence controllers
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _radiusController = TextEditingController();
    _loadSchoolSummary();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  // Load school statistics, roster, history, geofence parameters from backend
  Future<void> _loadSchoolSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await _attendanceRepo.fetchSchoolSummary();
      if (response['success'] == true) {
        setState(() {
          _dashboardData = response['data'];
          _isLoading = false;
        });
        
        // Prep Geofence Controller text
        final prof = _dashboardData?['profile'];
        if (prof != null) {
          _latController.text = (prof['latitude'] ?? '').toString();
          _lngController.text = (prof['longitude'] ?? '').toString();
          _radiusController.text = (prof['allowed_radius'] ?? '').toString();
        }
      } else {
        setState(() {
          _errorMessage = response['error'] ?? 'Failed to load school summary.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred connecting to backend: $e';
        _isLoading = false;
      });
    }
  }

  // Handle approving or rejecting trainer leaves
  Future<void> _handleLeaveStatus(int leaveId, String status) async {
    setState(() {
      _isActionLoading = true;
    });
    try {
      final response = await _attendanceRepo.updateLeaveStatus(
        leaveId: leaveId,
        status: status,
      );
      if (response['success'] == true) {
        _showSnackBar(
          'Leave request has been successfully ${status.toLowerCase()}ed!',
          const Color(0xFF10B981),
        );
        _loadSchoolSummary();
      } else {
        _showErrorSnackBar(response['error'] ?? 'Failed to update leave.');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isActionLoading = false;
      });
    }
  }

  // Handle geofence parameter updates
  Future<void> _handleUpdateGeofence() async {
    final double? lat = double.tryParse(_latController.text.trim());
    final double? lng = double.tryParse(_lngController.text.trim());
    final int? radius = int.tryParse(_radiusController.text.trim());

    if (lat == null || lng == null || radius == null) {
      _showErrorSnackBar('Please input valid numbers for GPS coordinate settings.');
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      final response = await _attendanceRepo.updateSchoolGeofence(
        latitude: lat,
        longitude: lng,
        allowedRadius: radius,
      );
      if (response['success'] == true) {
        _showSnackBar(
          'Dynamic GPS Geofencing configured successfully!',
          const Color(0xFF2563EB),
        );
        _loadSchoolSummary();
      } else {
        _showErrorSnackBar(response['error'] ?? 'Failed to update geofence.');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isActionLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _authRepo.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String err) {
    _showSnackBar(err, const Color(0xFFEF4444));
  }

  // Visual dialog to view full face selfie uploaded during check-in
  void _showSelfieDialog(String trainerName, String selfieUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.white,
                title: Text(
                  '$trainerName - Verification Selfie',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    selfieUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 250,
                        width: 250,
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(LucideIcons.imageOff, size: 48, color: Color(0xFF94A3B8)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close Panel',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(String tab, String label, IconData icon) {
    final bool isSelected = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _activeTab = tab;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    size: 18,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.profile['username'] as String? ?? 'School';
    final String capitalizedUsername = username.isNotEmpty
        ? '${username[0].toUpperCase()}${username.substring(1)}'
        : 'School';

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Premium Light Background
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(LucideIcons.menu, color: Color(0xFF0F172A)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: Text(
                _activeTab == 'dashboard' ? 'School Panel' : _activeTab.toUpperCase(),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF2563EB), size: 18),
                  onPressed: _loadSchoolSummary,
                )
              ],
            )
          : null,
      drawer: !isDesktop
          ? Drawer(
              child: _buildSidebar(capitalizedUsername),
            )
          : null,
      body: Row(
        children: [
          // ==================== SIDEBAR ====================
          if (isDesktop) _buildSidebar(capitalizedUsername),

          // ==================== MAIN CONTENT ====================
          Expanded(
            child: Container(
              height: double.infinity,
              color: const Color(0xFFF8FAFC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar (Only in Desktop)
                  if (isDesktop)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 18.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _activeTab == 'dashboard' 
                                ? 'School Dashboard' 
                                : _activeTab.toUpperCase().replaceAll('-', ' '),
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF2563EB), size: 18),
                                tooltip: 'Refresh Data',
                                onPressed: _loadSchoolSummary,
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.school, color: Color(0xFF2563EB), size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      capitalizedUsername,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2563EB),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  if (isDesktop) const Divider(color: Color(0xFFE2E8F0), height: 1),

                  // Content view
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2563EB),
                            ),
                          )
                        : _errorMessage.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.alertTriangle, size: 48, color: Color(0xFFEF4444)),
                                      const SizedBox(height: 16),
                                      Text(
                                        _errorMessage,
                                        style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                        ),
                                        onPressed: _loadSchoolSummary,
                                        icon: const Icon(LucideIcons.refreshCw),
                                        label: const Text('Try Again'),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 32.0 : 16.0,
                                        vertical: 24.0,
                                      ),
                                      child: _buildActiveView(capitalizedUsername),
                                    ),
                                  ),
                                  if (_isActionLoading)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.white.withOpacity(0.4),
                                        child: const Center(
                                          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebar(String schoolName) {
    return Container(
      width: 270,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.school,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROVOLO',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'SHAPING SKILLS. BUILDING FUTURES',
                      style: GoogleFonts.inter(
                        fontSize: 7.5,
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Navigation Tabs
          Expanded(
            child: ListView(
              children: [
                _buildSidebarItem('dashboard', 'Dashboard', LucideIcons.layoutDashboard),
                _buildSidebarItem('trainers', 'Trainers Roster', LucideIcons.users),
                _buildSidebarItem('attendance', 'Attendance Logs', LucideIcons.userCheck),
                _buildSidebarItem('reports', 'Reports', LucideIcons.fileSpreadsheet),
                _buildSidebarItem('profile', 'School Profile', LucideIcons.school),
                _buildSidebarItem('settings', 'Settings', LucideIcons.settings),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _handleLogout,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.logOut,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Logout',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEF4444),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),

          // Bottom School badge
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?auto=format&fit=crop&w=150&q=80',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schoolName,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'School Coordinator',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveView(String schoolName) {
    switch (_activeTab) {
      case 'trainers':
        return _buildTrainersListView();
      case 'attendance':
        return _buildAttendanceLogsView();
      case 'reports':
        return _buildReportsView();
      case 'profile':
        return _buildSchoolProfileView(schoolName);
      case 'settings':
        return _buildSettingsView();
      case 'dashboard':
      default:
        return _buildDashboardHome(schoolName);
    }
  }

  // ==================== SUB-VIEWS ====================

  // 1. Dashboard Home view (Dynamic Roster & Metrics)
  Widget _buildDashboardHome(String schoolName) {
    final trainers = _dashboardData?['roster'] as List? ?? [];
    final leaves = _dashboardData?['leave_queue'] as List? ?? [];

    final totalText = '${_dashboardData?['total_trainers'] ?? 0}';
    final presentText = '${_dashboardData?['present_trainers'] ?? 0}';
    final absentText = '${_dashboardData?['absent_trainers'] ?? 0}';
    final attendancePercentage = '${_dashboardData?['attendance_percentage'] ?? 100}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome to $schoolName Panel 🏫',
          style: GoogleFonts.outfit(
            fontSize: 24,
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Monitor assigned robotics trainer activities, approve leave applications, and configure geofence radius settings.',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 28),

        // Metrics Grid Row
        LayoutBuilder(
          builder: (context, constraints) {
            double cardWidth = (constraints.maxWidth - 48) / 4;
            if (constraints.maxWidth < 750) {
              return Column(
                children: [
                  Row(
                    children: [
                      _buildMetricTile('Total Trainers', totalText, 'Assigned Roster', LucideIcons.users, const Color(0xFF2563EB)),
                      const SizedBox(width: 12),
                      _buildMetricTile('Present Today', presentText, 'Checked In', LucideIcons.userCheck, const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMetricTile('Absent / Pending', absentText, 'Expected Logs', LucideIcons.userMinus, const Color(0xFFEF4444)),
                      const SizedBox(width: 12),
                      _buildMetricTile('Proportion', attendancePercentage, 'Daily Ratio', LucideIcons.lineChart, const Color(0xFFF59E0B)),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                _buildMetricTile('Total Trainers', totalText, 'Assigned Roster', LucideIcons.users, const Color(0xFF2563EB)),
                const SizedBox(width: 16),
                _buildMetricTile('Present Today', presentText, 'Checked In', LucideIcons.userCheck, const Color(0xFF10B981)),
                const SizedBox(width: 16),
                _buildMetricTile('Absent / Pending', absentText, 'Expected Logs', LucideIcons.userMinus, const Color(0xFFEF4444)),
                const SizedBox(width: 16),
                _buildMetricTile('Proportion', attendancePercentage, 'Daily Ratio', LucideIcons.lineChart, const Color(0xFFF59E0B)),
              ],
            );
          },
        ),
        const SizedBox(height: 36),

        // Assigned Trainer Status List
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TODAY\'S TRAINER CHECK-IN STATUS',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (trainers.isEmpty)
          _buildEmptyCard('No trainers have been assigned to this school roster yet.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trainers.length,
            itemBuilder: (context, index) {
              final t = trainers[index];
              return _buildTrainerStatusRow(t);
            },
          ),

        const SizedBox(height: 36),

        // Leave Requests Hub
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TRAINER LEAVE APPLICATIONS PENDING APPROVAL',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (leaves.isEmpty)
          _buildEmptyCard('No pending leave requests to process today.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leaves.length,
            itemBuilder: (context, index) {
              final l = leaves[index];
              return _buildLeaveRequestCard(l);
            },
          ),
      ],
    );
  }

  // 2. Trainers List View
  Widget _buildTrainersListView() {
    final trainers = _dashboardData?['roster'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Assigned Trainers Roster',
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        if (trainers.isEmpty)
          _buildEmptyCard('No trainers mapped to this school. Map them in the Admin Panel.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trainers.length,
            itemBuilder: (context, index) {
              final t = trainers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.user, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['name'] ?? 'Trainer',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            t['email'] ?? 'trainer@rovolo.com',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 12.5,
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          )
      ],
    );
  }

  // 3. Attendance Logs View (Table containing dynamic check ins/outs)
  Widget _buildAttendanceLogsView() {
    final logs = _dashboardData?['attendance_logs'] as List? ?? [];

    if (logs.isEmpty) {
      return _buildEmptyCard('No shift check-in logs submitted in this school center yet.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(label: Text('Trainer Name', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Date', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Check In', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Check Out', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Duration', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Selfie Check', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold))),
            ],
            rows: logs.map((row) {
              final selfieUrl = row['selfie_url'] as String?;
              return DataRow(
                cells: [
                  DataCell(Text(row['name'] ?? '--', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold))),
                  DataCell(Text(row['date'] ?? '--', style: GoogleFonts.inter(color: const Color(0xFF64748B)))),
                  DataCell(Text(row['in'] ?? '--', style: GoogleFonts.inter(color: const Color(0xFF64748B)))),
                  DataCell(Text(row['out'] ?? '--', style: GoogleFonts.inter(color: const Color(0xFF64748B)))),
                  DataCell(Text(row['working_hours'] ?? '--', style: GoogleFonts.inter(color: const Color(0xFF64748B)))),
                  DataCell(
                    selfieUrl != null
                        ? TextButton.icon(
                            onPressed: () => _showSelfieDialog(row['name'] ?? 'Trainer', selfieUrl),
                            icon: const Icon(LucideIcons.image, size: 14, color: Color(0xFF2563EB)),
                            label: Text(
                              'View Face',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Text('No Selfie', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 4. Reports View
  Widget _buildReportsView() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.fileText, color: Color(0xFF2563EB), size: 48),
          const SizedBox(height: 16),
          Text(
            'Dynamic Attendance Reports',
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetch latest schedules and export this school\'s monthly trainer check-in records into standard spreadsheets.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _showSnackBar('Compiling current month check-ins. Export starting shortly!', const Color(0xFF2563EB));
            },
            icon: const Icon(LucideIcons.download),
            label: const Text('Export Current Month Logs (CSV)'),
          )
        ],
      ),
    );
  }

  // 5. School Profile & Dynamic Coordinates Config
  Widget _buildSchoolProfileView(String schoolName) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sliders, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                'Configure GPS Geofence Boundary settings',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Calibrate allowed check-in center coordinates and boundary radius. All trainer check-in calls outside this geofence will be rejected.',
            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12.5),
          ),
          const SizedBox(height: 24),

          // Fields
          _buildGeofenceField('Registered School Name', schoolName, enabled: false),
          const Divider(color: Color(0xFFF1F5F9), height: 32),
          _buildGeofenceField(
            'Latitude Center Point', 
            '', 
            controller: _latController,
            placeholder: 'e.g. 28.6139',
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 32),
          _buildGeofenceField(
            'Longitude Center Point', 
            '', 
            controller: _lngController,
            placeholder: 'e.g. 77.2090',
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 32),
          _buildGeofenceField(
            'Geofencing Radius Proximity (meters)', 
            '', 
            controller: _radiusController,
            placeholder: 'e.g. 100',
          ),
          
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleUpdateGeofence,
              icon: const Icon(LucideIcons.save),
              label: Text(
                'Save Geofencing Boundaries',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGeofenceField(
    String label, 
    String staticVal, {
    bool enabled = true,
    TextEditingController? controller,
    String placeholder = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (!enabled)
          Text(
            staticVal,
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2.0),
              ),
            ),
          )
      ],
    );
  }

  // 6. Settings View
  Widget _buildSettingsView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Preferences',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: Text('Trainer GPS Check-in Notifications', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            subtitle: Text('Receive visual logs when trainers arrive at dynamic borders', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12.5)),
            value: true,
            activeColor: const Color(0xFF2563EB),
            onChanged: (val) {},
          )
        ],
      ),
    );
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildMetricTile(String label, String value, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            )
          ],
        ),
      ),
    );
  }

  // Row displaying trainer checked-in status today
  Widget _buildTrainerStatusRow(Map<String, dynamic> trainer) {
    final selfieUrl = trainer['selfie_url'] as String?;
    final colorVal = trainer['color'] as String? ?? '0xFF64748B';
    final statusColor = Color(int.parse(colorVal));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.user, color: Color(0xFF64748B), size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainer['name'] ?? 'Trainer',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (trainer['check_in_time'] != null)
                        Text(
                          'Checked in at ${trainer['check_in_time']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        )
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (selfieUrl != null) ...[
                TextButton.icon(
                  onPressed: () => _showSelfieDialog(trainer['name'] ?? 'Trainer', selfieUrl),
                  icon: const Icon(LucideIcons.camera, size: 14, color: Color(0xFF2563EB)),
                  label: Text(
                    'Verified Selfie',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trainer['status'] ?? 'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Row representing interactive pending trainer leaves with approve/reject buttons
  Widget _buildLeaveRequestCard(Map<String, dynamic> leave) {
    final leaveId = leave['id'] as int;
    final trainerName = leave['trainer_name'] ?? 'Trainer';
    final start = leave['start_date'] ?? '';
    final end = leave['end_date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trainerName,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  leave['leave_type'] ?? 'Leave',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFD97706),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Duration: $start to $end',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reason: "${leave['reason'] ?? ''}"',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleLeaveStatus(leaveId, 'rejected'),
                icon: const Icon(LucideIcons.xCircle, size: 14),
                label: Text('Reject Request', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleLeaveStatus(leaveId, 'approved'),
                icon: const Icon(LucideIcons.checkCircle, size: 14),
                label: Text('Approve Leave', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
