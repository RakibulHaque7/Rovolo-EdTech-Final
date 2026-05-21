import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' as intl;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../attendance/data/attendance_repository.dart';

class TrainerDashboard extends StatefulWidget {
  final Map<String, dynamic> profile;

  const TrainerDashboard({super.key, required this.profile});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  String _activeTab = 'dashboard'; 
  final AuthRepository _authRepo = AuthRepository();
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final ImagePicker _picker = ImagePicker();

  // State Variables
  bool _isLoading = true;
  bool _isActionLoading = false;
  bool _isLocationLoading = false;
  
  // Real stats loaded from API
  bool _alreadyCheckedIn = false;
  bool _alreadyCheckedOut = false;
  String _workingHoursToday = "0h 0m";
  int _totalLeaves = 0;
  int _pendingLeaves = 0;
  int _approvedLeaves = 0;

  // GPS Proximity State
  double? _currentLat;
  double? _currentLng;
  double? _distance;
  bool _isWithinBoundary = false;
  bool _mockLocation = true; // Enabled by default for local dev ease!

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Load live statistics from backend APIs
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await _attendanceRepo.fetchDashboardSummary();
      if (summary['success'] == true) {
        final data = summary['data'];
        setState(() {
          _alreadyCheckedIn = data['today_attendance'] ?? false;
          _workingHoursToday = data['working_hours_today'] ?? "0h 0m";
          _totalLeaves = data['total_leaves'] ?? 0;
          _pendingLeaves = data['pending_leaves'] ?? 0;
          _approvedLeaves = data['approved_leaves'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }

    _checkLocationProximity();
  }

  // Calculate real distance or mock it for test ease
  Future<void> _checkLocationProximity() async {
    final assignedSchool = widget.profile['assigned_school'] as Map<String, dynamic>?;
    if (assignedSchool == null) return;

    final double? schoolLat = (assignedSchool['latitude'] as num?)?.toDouble();
    final double? schoolLng = (assignedSchool['longitude'] as num?)?.toDouble();
    final int allowedRadius = (assignedSchool['allowed_radius'] as num?)?.toInt() ?? 100;

    if (schoolLat == null || schoolLng == null) return;

    setState(() {
      _isLocationLoading = true;
    });

    if (_mockLocation) {
      setState(() {
        _currentLat = schoolLat;
        _currentLng = schoolLng;
        _distance = 0.0;
        _isWithinBoundary = true;
        _isLocationLoading = false;
      });
    } else {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
          setState(() {
            _isLocationLoading = false;
          });
          _showErrorSnackBar("GPS permission is required to fetch proximity.");
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final double distanceInMeters = Geolocator.distanceBetween(
          schoolLat,
          schoolLng,
          position.latitude,
          position.longitude,
        );

        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
          _distance = distanceInMeters;
          _isWithinBoundary = distanceInMeters <= allowedRadius;
          _isLocationLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLocationLoading = false;
        });
        _showErrorSnackBar("Could not fetch GPS: $e");
      }
    }
  }

  // Selfie camera check-in
  Future<void> _handleCheckIn() async {
    if (!_isWithinBoundary) {
      _showErrorSnackBar("You are outside the school boundary radius limits!");
      return;
    }

    if (_currentLat == null || _currentLng == null) {
      _showErrorSnackBar("GPS coordinates not acquired yet. Please refresh location.");
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      final XFile? selfie = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (selfie == null) {
        setState(() {
          _isActionLoading = false;
        });
        _showErrorSnackBar("Selfie photo capture was cancelled.");
        return;
      }

      final result = await _attendanceRepo.checkIn(
        latitude: _currentLat!,
        longitude: _currentLng!,
        selfieFile: selfie,
      );

      if (result['success'] == true) {
        _showSuccessSnackBar("Check-in completed successfully!");
        _loadDashboardData();
        setState(() {
          _activeTab = 'dashboard';
        });
      } else {
        _showErrorSnackBar(result['error'] ?? "Failed to check in.");
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() {
        _isActionLoading = false;
      });
    }
  }

  // Selfie check-out
  Future<void> _handleCheckOut() async {
    if (_currentLat == null || _currentLng == null) {
      _showErrorSnackBar("GPS coordinates not acquired yet. Please refresh location.");
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      final result = await _attendanceRepo.checkOut(
        latitude: _currentLat!,
        longitude: _currentLng!,
      );

      if (result['success'] == true) {
        _showSuccessSnackBar("Check-out completed! Hours logged: ${result['working_hours']}h");
        _loadDashboardData();
        setState(() {
          _activeTab = 'dashboard';
        });
      } else {
        _showErrorSnackBar(result['error'] ?? "Failed to check out.");
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSidebarItem(String tab, String label, IconData icon) {
    final bool isSelected = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent, 
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
                    color: isSelected ? Colors.white : const Color(0xFF64748B), // Clear slate grey
                    size: 18,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : const Color(0xFF64748B), // Slate grey
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    final username = widget.profile['username'] as String? ?? 'Trainer';
    final String capitalizedUsername = username.isNotEmpty
        ? '${username[0].toUpperCase()}${username.substring(1)}'
        : 'Trainer';

    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Row(
              children: [
                // ==================== SIDEBAR ====================
                Container(
                  width: 270,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC), // Off-white sidebar
                    border: Border(
                      right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5), // Slate border
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
                                color: const Color(0xFFEFF6FF), // Light blue cap background
                                border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.graduationCap,
                                color: Color(0xFF2563EB), // Royal Blue
                                size: 18,
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
                                    color: const Color(0xFF0F172A), // Bold dark text
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  'SHAPING SKILLS. BUILDING FUTURES',
                                  style: GoogleFonts.inter(
                                    fontSize: 7.5,
                                    color: const Color(0xFF2563EB), // Premium Royal Blue
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
                            _buildSidebarItem('check-in', 'Check-In', LucideIcons.logIn),
                            _buildSidebarItem('check-out', 'Check-Out', LucideIcons.logOut),
                            _buildSidebarItem('history', 'Attendance History', LucideIcons.history),
                            _buildSidebarItem('analytics', 'Monthly Analytics', LucideIcons.lineChart),
                            _buildSidebarItem('leave', 'Leave', LucideIcons.clock),
                            _buildSidebarItem('profile', 'Profile', LucideIcons.user),
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
                                              fontWeight: FontWeight.w600,
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

                      // Bottom Badge
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9), // Slate 100 light background
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
                                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
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
                                      capitalizedUsername,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        color: const Color(0xFF0F172A), // Dark slate text
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Robotics Trainer',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
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
                ),

                // ==================== MAIN CONTENT ====================
                Expanded(
                  child: Container(
                    height: double.infinity,
                    color: Colors.white, // Light main background
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 18.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _activeTab == 'dashboard' 
                                    ? 'Trainer Dashboard' 
                                    : _activeTab.toUpperCase().replaceAll('-', ' '),
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  color: const Color(0xFF0F172A), // Dark slate text
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(LucideIcons.bell, color: Color(0xFF334155), size: 20),
                                  const SizedBox(width: 20),
                                  Text(
                                    capitalizedUsername,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF0F172A), // Dark slate text
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        const Divider(color: Color(0xFFE2E8F0), height: 1),

                        Expanded(
                          child: _isActionLoading 
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(32.0),
                                  child: _buildActiveView(capitalizedUsername),
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

  Widget _buildActiveView(String username) {
    switch (_activeTab) {
      case 'check-in':
        return _buildCheckInView();
      case 'check-out':
        return _buildCheckOutView();
      case 'history':
        return _buildHistoryView();
      case 'analytics':
        return _buildAnalyticsView();
      case 'leave':
        return _buildLeaveView();
      case 'profile':
        return _buildProfileView();
      case 'dashboard':
      default:
        return _buildHomeView(username);
    }
  }

  // ==================== SUB-VIEWS ====================

  // 1. Home Dashboard view
  Widget _buildHomeView(String username) {
    final assignedSchool = widget.profile['assigned_school'] as Map<String, dynamic>?;
    final String schoolName = assignedSchool?['name'] ?? 'No School Assigned';
    final String todayDate = intl.DateFormat('dd MMMM yyyy').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $username! 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Here is your shift metrics summary for today.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 13.5,
                  ),
                )
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                todayDate,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 32),

        // Metrics Grid Row
        Row(
          children: [
            _buildMetricTile('Present Days', '18 Days', 'This Month', LucideIcons.checkCircle, const Color(0xFF10B981)),
            const SizedBox(width: 16),
            _buildMetricTile('Absent Days', '2 Days', 'This Month', LucideIcons.xCircle, const Color(0xFFEF4444)),
            const SizedBox(width: 16),
            _buildMetricTile('Working Hours', _workingHoursToday, 'Today Logged', LucideIcons.clock, const Color(0xFFF59E0B)),
            const SizedBox(width: 16),
            _buildMetricTile('Assigned School', schoolName, 'Active Mapping', LucideIcons.school, const Color(0xFF3B82F6)),
          ],
        ),
        const SizedBox(height: 36),

        // Quick Actions block
        Text(
          'QUICK SHIFT CONTROLS',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickControlCard(
                'Check-In Shift',
                'Take attendance with front selfie & location verification.',
                'Go to Check-In',
                LucideIcons.logIn,
                const Color(0xFF10B981),
                () => setState(() => _activeTab = 'check-in'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickControlCard(
                'Check-Out Shift',
                'Calculate working duration and stop location tracker.',
                'Go to Check-Out',
                LucideIcons.logOut,
                const Color(0xFFEF4444),
                () => setState(() => _activeTab = 'check-out'),
              ),
            ),
          ],
        )
      ],
    );
  }

  // 2. Check-In View
  Widget _buildCheckInView() {
    final assignedSchool = widget.profile['assigned_school'] as Map<String, dynamic>?;
    final String schoolName = assignedSchool?['name'] ?? 'No School Assigned';
    final int allowedRadius = assignedSchool?['allowed_radius'] ?? 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Simulated Proximity Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.terminal, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Simulate Proximity Boundary (For Local Coding)',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _mockLocation,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setState(() {
                    _mockLocation = val;
                  });
                  _checkLocationProximity();
                },
              )
            ],
          ),
        ),
        const SizedBox(height: 24),

        // School Information Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.school, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      assignedSchool != null 
                          ? 'Boundary: $allowedRadius meters | GPS Locked'
                          : 'No active coordinate mapping configured.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Proximity Indicator
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isWithinBoundary 
                ? const Color(0xFF10B981).withOpacity(0.08) 
                : const Color(0xFFEF4444).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isWithinBoundary 
                  ? const Color(0xFF10B981).withOpacity(0.3) 
                  : const Color(0xFFEF4444).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isWithinBoundary ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
                color: _isWithinBoundary ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isWithinBoundary ? 'Inside Check-in Boundary' : 'Outside Check-in Boundary',
                      style: GoogleFonts.outfit(
                        color: _isWithinBoundary ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _distance != null 
                          ? 'You are standing ${_distance!.toStringAsFixed(1)}m away.'
                          : 'Proximity boundary could not be measured.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF64748B), size: 18),
                onPressed: _checkLocationProximity,
              )
            ],
          ),
        ),
        const SizedBox(height: 36),

        // Action Button
        if (_alreadyCheckedIn)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.checkSquare, color: Color(0xFF059669)),
                const SizedBox(width: 12),
                Text(
                  'Already Checked In Today!',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF059669),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _handleCheckIn,
            icon: const Icon(LucideIcons.camera),
            label: Text(
              'Capture Selfie & Check-In',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  // 3. Check-Out View
  Widget _buildCheckOutView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(LucideIcons.clock, color: Color(0xFFF59E0B), size: 48),
              const SizedBox(height: 20),
              Text(
                'Complete Shift Check-Out',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This will calculate your final logged time and stop backend tracking.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        if (!_alreadyCheckedIn)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626)),
                const SizedBox(width: 12),
                Text(
                  'Cannot Check-Out! You are not checked in yet.',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFDC2626),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _handleCheckOut,
            icon: const Icon(LucideIcons.logOut),
            label: Text(
              'End Shift & Check-Out',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  // 4. Attendance History View
  Widget _buildHistoryView() {
    final mockHistory = [
      {"date": "18 May 2026", "school": "Green Valley School", "in": "09:00 AM", "out": "05:00 PM", "hours": "8.0 hrs", "status": "Present"},
      {"date": "17 May 2026", "school": "Green Valley School", "in": "08:58 AM", "out": "05:10 PM", "hours": "8.2 hrs", "status": "Present"},
      {"date": "16 May 2026", "school": "Green Valley School", "in": "09:05 AM", "out": "04:55 PM", "hours": "7.8 hrs", "status": "Present"},
      {"date": "15 May 2026", "school": "Green Valley School", "in": "09:00 AM", "out": "05:00 PM", "hours": "8.0 hrs", "status": "Present"},
    ];

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2), // Date
        1: FlexColumnWidth(3), // School
        2: FlexColumnWidth(2), // Check In
        3: FlexColumnWidth(2), // Check Out
        4: FlexColumnWidth(2), // Total Hours
        5: FlexColumnWidth(2), // Status
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
          ),
          children: [
            _buildTableHeader('Date'),
            _buildTableHeader('School'),
            _buildTableHeader('In'),
            _buildTableHeader('Out'),
            _buildTableHeader('Duration'),
            _buildTableHeader('Status'),
          ],
        ),
        ...mockHistory.map((row) {
          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.0)),
            ),
            children: [
              _buildTableCell(row['date']!, isBold: true),
              _buildTableCell(row['school']!),
              _buildTableCell(row['in']!),
              _buildTableCell(row['out']!),
              _buildTableCell(row['hours']!),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      row['status']!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF059669),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList()
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF64748B),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: isBold ? const Color(0xFF0F172A) : const Color(0xFF475569),
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  // 5. Monthly Analytics View
  Widget _buildAnalyticsView() {
    final List<dynamic> points = [
      {"label": "Week 1", "value": 100.0},
      {"label": "Week 2", "value": 90.0},
      {"label": "Week 3", "value": 100.0},
      {"label": "Week 4", "value": 95.0},
    ];

    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Trends (Current Month)',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: SimpleLinePainter(points: points),
            ),
          )
        ],
      ),
    );
  }

  // 6. Leave View
  Widget _buildLeaveView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit Leave Request',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Reason for Leave',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(color: Color(0xFF0F172A)),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  _showSuccessSnackBar("Leave request submitted to school for approval!");
                },
                child: Text(
                  'Submit Request',
                  style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 7. Profile View
  Widget _buildProfileView() {
    final email = widget.profile['email'] ?? 'trainer@rovolo.com';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileRow('Username', widget.profile['username'] ?? 'Trainer'),
          const Divider(color: Color(0xFFE2E8F0), height: 32),
          _buildProfileRow('Email Address', email),
          const Divider(color: Color(0xFFE2E8F0), height: 32),
          _buildProfileRow('System Role', 'Robotics Trainer'),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        )
      ],
    );
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildMetricTile(String label, String value, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickControlCard(String title, String desc, String btnLabel, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  btnLabel,
                  style: GoogleFonts.inter(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.arrowRight, color: color, size: 16),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class SimpleLinePainter extends CustomPainter {
  final List<dynamic> points;

  SimpleLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final paintOuterDot = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    final textStyle = GoogleFonts.inter(
      color: const Color(0xFF64748B),
      fontSize: 10.0,
    );

    final double segmentWidth = size.width / (points.length - 1);
    final coords = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final double x = i * segmentWidth;
      final double val = (points[i]['value'] as num).toDouble();
      final double y = size.height - (val / 100.0 * size.height);
      coords.add(Offset(x, y));

      final labelSpan = TextSpan(text: points[i]['label'], style: textStyle);
      final labelPainter = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)..layout();
      labelPainter.paint(canvas, Offset(x - labelPainter.width / 2, size.height + 12));
    }

    final path = Path()..moveTo(coords[0].dx, coords[0].dy);
    for (int i = 1; i < coords.length; i++) {
      path.lineTo(coords[i].dx, coords[i].dy);
    }
    canvas.drawPath(path, paintLine);

    for (var pt in coords) {
      canvas.drawCircle(pt, 6, paintOuterDot);
      canvas.drawCircle(pt, 4, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
