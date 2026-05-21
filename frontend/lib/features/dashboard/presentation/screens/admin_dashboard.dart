import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../attendance/data/attendance_repository.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> profile;

  const AdminDashboard({super.key, required this.profile});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthRepository _authRepo = AuthRepository();
  final AttendanceRepository _attendanceRepo = AttendanceRepository();

  bool _isLoading = true;
  bool _isPageLoading = false;
  String _activeTab = 'dashboard';

  // Stats loaded from Admin Summary API
  int _totalSchools = 0;
  int _totalTrainers = 0;
  int _totalStudents = 0;
  int _todayAttendanceCount = 0;
  double _todayAttendancePercentage = 0.0;

  List<dynamic> _recentReports = [];
  List<dynamic> _weeklyOverview = [];
  List<dynamic> _schoolShares = [];

  Map<String, dynamic>? _todayReport;
  Map<String, dynamic>? _monthlyAnalyticsData;
  List<dynamic> _attendanceHistory = [];
  List<dynamic> _leaveRequests = [];
  List<dynamic> _schools = [];
  List<dynamic> _trainers = [];
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await _attendanceRepo.fetchAdminSummary();

      // Debug: print entire summary for visibility when values are missing
      debugPrint('Admin summary raw: $summary');

      // If backend returned a data payload even when `success` is false (e.g., auth issues),
      // prefer to use any available `data` to populate the UI and show a warning.
      final Map<String, dynamic>? dataFromResponse = (summary['data'] is Map) ? Map<String, dynamic>.from(summary['data']) : null;

      if (summary['success'] == true || (dataFromResponse != null && dataFromResponse.isNotEmpty)) {
        final data = dataFromResponse ?? summary['data'];
        setState(() {
          _totalSchools = data['total_schools'] ?? 0;
          _totalTrainers = data['total_trainers'] ?? 0;
          _totalStudents = data['total_students'] ?? 0;
          _todayAttendanceCount = data['today_attendance_count'] ?? 0;

          _todayAttendancePercentage = (data['today_attendance_percentage'] as num?)?.toDouble() ?? 0.0;

          _recentReports = data['recent_class_reports'] ?? [];
          _weeklyOverview = data['weekly_overview'] ?? [];
          _schoolShares = data['attendance_by_school'] ?? [];

          _isLoading = false;
        });

        // If the fetch wasn't successful but returned data, show a non-blocking warning
        if (summary['success'] != true && summary['error'] != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Warning: ${summary['error']}')),
          );
        }
      } else {
        // No usable data returned
        if (summary['error'] != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading dashboard: ${summary['error']}')),
          );
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Admin summary fetch exception: $e');
      setState(() {
        _isLoading = false;
      });
      _loadFallbackMockData();
    }
  }

 void _loadFallbackMockData() {
  setState(() {
    _recentReports = [];

    _weeklyOverview = [];

    _schoolShares = [];

    _isLoading = false;
  });
}

  Future<void> _loadPageData(String tab) async {
    setState(() {
      _isPageLoading = true;
    });

    try {
      switch (tab) {
        case 'reports':
          await Future.wait([
            _fetchAttendanceReport(),
            _fetchAttendanceHistory(),
          ]);
          break;
        case 'analytics':
          await _fetchMonthlyAnalytics();
          break;
        case 'leaves':
          await _fetchLeaveRequests();
          break;
        case 'schools':
          await _fetchSchools();
          break;
        case 'trainers':
          await _fetchTrainers();
          break;
        case 'users':
          await _fetchUsers();
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Page data load failed for $tab: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load $tab data.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAttendanceReport() async {
    final response = await _attendanceRepo.fetchAttendanceReport();
    if (response['success'] == true) {
      _todayReport = response['data'];
    }
  }

  Future<void> _fetchMonthlyAnalytics() async {
    final response = await _attendanceRepo.fetchMonthlyAnalytics();
    if (response['success'] == true) {
      _monthlyAnalyticsData = response['data'];
    }
  }

  Future<void> _fetchAttendanceHistory() async {
    final response = await _attendanceRepo.fetchAttendanceHistory();
    if (response['success'] == true) {
      _attendanceHistory = List<dynamic>.from(response['data'] as List? ?? []);
    }
  }

  Future<void> _fetchLeaveRequests() async {
    final response = await _attendanceRepo.fetchLeaveHistory();
    if (response['success'] == true) {
      _leaveRequests = List<dynamic>.from(response['data'] as List? ?? []);
    }
  }

  Future<void> _fetchSchools() async {
    final response = await _attendanceRepo.fetchSchoolList();
    if (response['success'] == true) {
      _schools = List<dynamic>.from(response['data'] as List? ?? []);
    }
  }

  Future<void> _fetchTrainers() async {
    final response = await _attendanceRepo.fetchUsers(role: 'trainer');
    if (response['success'] == true) {
      _trainers = List<dynamic>.from(response['data'] as List? ?? []);
    }
  }

  Future<void> _fetchUsers() async {
    final response = await _attendanceRepo.fetchUsers();
    if (response['success'] == true) {
      _users = List<dynamic>.from(response['data'] as List? ?? []);
    }
  }

  void _switchTab(String tab) {
    if (_activeTab == tab) {
      return;
    }

    setState(() {
      _activeTab = tab;
    });

    _loadPageData(tab);
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

  Widget _buildActiveView() {
    switch (_activeTab) {
      case 'reports':
        return _buildReportsPage();
      case 'analytics':
        return _buildAnalyticsPage();
      case 'leaves':
        return _buildLeavesPage();
      case 'schools':
        return _buildSchoolsPage();
      case 'trainers':
        return _buildTrainersPage();
      case 'users':
        return _buildUsersPage();
      case 'settings':
        return _buildSettingsPage();
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) {
            return Row(
              children: [
                _buildMetricCard('Total Schools', '$_totalSchools', 'Registered Branches', LucideIcons.school, const Color(0xFF2563EB)),
                const SizedBox(width: 18),
                _buildMetricCard('Active Trainers', '$_totalTrainers', 'Assigned Instructors', LucideIcons.users, Colors.purple),
                const SizedBox(width: 18),
                _buildMetricCard('Total Students', '$_totalStudents', 'Registered Pupils', LucideIcons.graduationCap, Colors.teal),
                const SizedBox(width: 18),
                _buildMetricCard('Attendance Rate', '${_todayAttendancePercentage.toStringAsFixed(1)}%', 'Present Ratio Today', LucideIcons.checkCircle, Colors.green),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Overview (This Week)',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: LineChartPainter(dataPoints: _weeklyOverview),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Container(
                height: 350,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance by School',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: DonutChartPainter(
                                  shares: _schoolShares,
                                  average: _todayAttendancePercentage,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _schoolShares.length,
                              itemBuilder: (context, idx) {
                                final colors = [
                                  const Color(0xFF2563EB),
                                  Colors.purple,
                                  Colors.teal,
                                  Colors.orange
                                ];
                                final item = _schoolShares[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: colors[idx % colors.length],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item['name'] ?? 'School',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF475569),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${(item['percentage'] as num?)?.toInt()}%',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Class Reports',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All Reports',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF2563EB),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildReportsTable(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Project Uploads',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All Projects',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF2563EB),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProjectTile(
                      'Smart Irrigation System',
                      'Class 9A - Green Valley School',
                      '20 May, 09:20 AM',
                      'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=100&q=80',
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 24),
                    _buildProjectTile(
                      'Obstacle Avoiding Robot',
                      'Class 8B - Sunrise School',
                      '19 May, 03:10 PM',
                      'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?auto=format&fit=crop&w=100&q=80',
                    ),
                  ],
                ),
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildReportsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Attendance Reports',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _todayReport == null
              ? const Text('No attendance report available yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Today\'s Summary',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        _buildInfoCard('Present', '${_todayReport?['present'] ?? '0'}'),
                        _buildInfoCard('Absent', '${_todayReport?['absent'] ?? '0'}'),
                        _buildInfoCard('Late', '${_todayReport?['late'] ?? '0'}'),
                        _buildInfoCard('Attendance %', '${(_todayReport?['attendance_percentage'] ?? 0).toString()}%'),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Attendance History', 'Refresh', () => _loadPageData('reports')),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _attendanceHistory.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No attendance history has been loaded for this view yet.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                )
              : Column(
                  children: _attendanceHistory.map((record) {
                    return ListTile(
                      title: Text(record['student_name'] ?? 'Student', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text('${record['school'] ?? 'School'} • ${record['date'] ?? ''}', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      trailing: Text(record['status'] ?? 'Present', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Monthly Analytics',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _monthlyAnalyticsData == null
              ? const Text('No analytics data available yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Monthly Overview',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        _buildInfoCard('Present', '${_monthlyAnalyticsData?['present'] ?? '0'}'),
                        _buildInfoCard('Absent', '${_monthlyAnalyticsData?['absent'] ?? '0'}'),
                        _buildInfoCard('Late', '${_monthlyAnalyticsData?['late'] ?? '0'}'),
                        _buildInfoCard('Average %', '${_monthlyAnalyticsData?['average_percentage'] ?? '0'}%'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Monthly Trend',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 280,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: LineChartPainter(dataPoints: List<dynamic>.from(_monthlyAnalyticsData?['trend'] ?? [])),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLeavesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Leave Requests',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _leaveRequests.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No leave requests found.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                )
              : Column(
                  children: _leaveRequests.map((leave) {
                    return ListTile(
                      title: Text(leave['student_name'] ?? leave['employee_name'] ?? 'Applicant', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text('${leave['school'] ?? 'School'} • ${leave['from_date'] ?? leave['start_date'] ?? ''} - ${leave['to_date'] ?? leave['end_date'] ?? ''}', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      trailing: Text(leave['status'] ?? 'Pending', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSchoolsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Schools',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _schools.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No schools found.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                )
              : Column(
                  children: _schools.map((school) {
                    return ListTile(
                      title: Text(school['name'] ?? 'School', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text(school['location'] ?? 'Location unknown', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      trailing: Text(school['status'] ?? 'Active', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTrainersPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Trainers',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _trainers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No trainers found.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                )
              : Column(
                  children: _trainers.map((trainer) {
                    return ListTile(
                      title: Text(trainer['name'] ?? trainer['username'] ?? 'Trainer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text(trainer['email'] ?? '', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      trailing: Text(trainer['status'] ?? 'Active', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildUsersPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Users',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _users.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No users found.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                )
              : Column(
                  children: _users.map((user) {
                    return ListTile(
                      title: Text(user['name'] ?? user['username'] ?? 'User', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text(user['email'] ?? '', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      trailing: Text(user['role'] ?? 'Member', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Settings',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'Admin settings are not configured yet. Please select an option from the sidebar.',
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String actionLabel, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: action,
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                color: const Color(0xFF2563EB),
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String tab, String label, IconData icon) {
    final bool isSelected = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent, // Blue on click/active
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _switchTab(tab);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    size: 18,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : const Color(0xFF0F172A), // Dark bold text by default
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
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
    final username = widget.profile['username'] as String? ?? 'Admin';
    final String capitalizedUsername = username.isNotEmpty
        ? '${username[0].toUpperCase()}${username.substring(1)}'
        : 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // White/slate clean background
      body: Row(
        children: [
          // ==================== SIDEBAR ====================
          Container(
            width: 270,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white, // White background
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5), // Slate border
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                // Rovolo Branding Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.graduationCap,
                          color: Color(0xFF2563EB),
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
                              color: const Color(0xFF0F172A), // Dark bold text
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'SHAPING SKILLS. BUILDING FUTURES',
                            style: GoogleFonts.inter(
                              fontSize: 7.5,
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
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
                    physics: const ClampingScrollPhysics(),
                    children: [
                      _buildSidebarItem('dashboard', 'Dashboard', LucideIcons.layoutDashboard),
                      _buildSidebarItem('reports', 'Attendance Reports', LucideIcons.fileSpreadsheet),
                      _buildSidebarItem('analytics', 'Monthly Analytics', LucideIcons.lineChart),
                      _buildSidebarItem('leaves', 'Leave Requests', LucideIcons.clock),
                      _buildSidebarItem('schools', 'Schools', LucideIcons.school),
                      _buildSidebarItem('trainers', 'Trainers', LucideIcons.users),
                      _buildSidebarItem('users', 'Users', LucideIcons.userCheck),
                      _buildSidebarItem('settings', 'Settings', LucideIcons.settings),
                      const SizedBox(height: 16),
                      // Custom Logout Tab
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
                                        fontWeight: FontWeight.bold,
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

                // Bottom Admin Badge
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
                            color: const Color(0xFFEFF6FF),
                          ),
                          child: const Icon(LucideIcons.user, color: Color(0xFF2563EB), size: 18),
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
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'System Superuser',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
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

          // ==================== MAIN CONTENT AREA ====================
          Expanded(
            child: Container(
              height: double.infinity,
              color: const Color(0xFFF8FAFC), // Soft white background
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 18.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.menu, color: Color(0xFF475569), size: 24),
                            const SizedBox(width: 16),
                            Text(
                              'Admin Dashboard',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                color: const Color(0xFF0F172A), // Dark bold text
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.bell, color: Color(0xFF475569), size: 20),
                              onPressed: () {},
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                Container(
                                  height: 32,
                                  width: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFEFF6FF),
                                  ),
                                  child: const Icon(LucideIcons.userCheck, color: Color(0xFF2563EB), size: 16),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  capitalizedUsername,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF0F172A), // Dark bold text
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(LucideIcons.chevronDown, color: Color(0xFF475569), size: 16),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),

                  // Content Body
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                        : _isPageLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_activeTab == 'dashboard') ...[
                                      _buildDashboardOverview(),
                                    ] else ...[
                                      _buildActiveView(),
                                    ],
                                  ],
                                ),
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

  // Analytics Metrics Top Card Builder
  Widget _buildMetricCard(String title, String count, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF475569),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    count,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            )
          ],
        ),
      ),
    );
  }

  // Recent Class Reports Table Builder
  Widget _buildReportsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2), // Trainer
        1: FlexColumnWidth(3), // School
        2: FlexColumnWidth(2), // Class
        3: FlexColumnWidth(3), // Topic
        4: FlexColumnWidth(2), // Date
        5: FlexColumnWidth(2), // Status
      },
      children: [
        // Table Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
          ),
          children: [
            _buildTableHeaderCell('Trainer'),
            _buildTableHeaderCell('School'),
            _buildTableHeaderCell('Class'),
            _buildTableHeaderCell('Topic'),
            _buildTableHeaderCell('Date'),
            _buildTableHeaderCell('Status'),
          ],
        ),
        ..._recentReports.map((report) {
          return TableRow(
            children: [
              _buildTableCell(report['trainer'] ?? 'Trainer', isBold: true),
              _buildTableCell(report['school'] ?? 'School'),
              _buildTableCell(report['class_division'] ?? 'Class'),
              _buildTableCell(report['topic'] ?? 'Topic'),
              _buildTableCell(report['date'] ?? 'Date'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report['status'] ?? 'Submitted',
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

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF475569),
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
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

  Widget _buildProjectTile(String title, String subtitle, String date, String imageUrl) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF475569),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

// ==================== LIGHT THEMED CUSTOM PAINTERS: CHARTS ====================

class LineChartPainter extends CustomPainter {
  final List<dynamic> dataPoints;

  LineChartPainter({required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paintLine = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDot = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final paintOuterDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final paintGrid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    final textStyle = GoogleFonts.inter(
      color: const Color(0xFF64748B),
      fontSize: 10.0,
      fontWeight: FontWeight.bold,
    );

    const int gridRows = 4;
    final double rowHeight = size.height / gridRows;
    for (int i = 0; i <= gridRows; i++) {
      final double y = i * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
      
      final percentage = (gridRows - i) * 25;
      final textSpan = TextSpan(text: '$percentage%', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(-32, y - textPainter.height / 2));
    }

    final double widthSegment = size.width / (dataPoints.length - 1);
    final points = <Offset>[];
    
    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * widthSegment;
      final double value = (dataPoints[i]['value'] as num).toDouble();
      
      final double y = size.height - (value / 100.0 * size.height);
      points.add(Offset(x, y));

      final labelSpan = TextSpan(text: dataPoints[i]['label'] ?? '', style: textStyle);
      final labelPainter = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)..layout();
      labelPainter.paint(canvas, Offset(x - labelPainter.width / 2, size.height + 12));
    }

    final pathFill = Path()..moveTo(0, size.height);
    for (var point in points) {
      pathFill.lineTo(point.dx, point.dy);
    }
    pathFill.lineTo(size.width, size.height);
    pathFill.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF2563EB).withOpacity(0.15), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(pathFill, fillPaint);

    final pathLine = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      pathLine.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(pathLine, paintLine);

    for (var pt in points) {
      canvas.drawCircle(pt, 6, paintOuterDot);
      canvas.drawCircle(pt, 4, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutChartPainter extends CustomPainter {
  final List<dynamic> shares;
  final double average;

  DonutChartPainter({required this.shares, required this.average});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double thickness = 18.0;

    final colors = [
      const Color(0xFF2563EB),
      Colors.purple,
      Colors.teal,
      Colors.orange
    ];

    double totalVal = 0;
    for (var item in shares) {
      totalVal += (item['percentage'] as num).toDouble();
    }

    if (totalVal == 0) return;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < shares.length; i++) {
      final double val = (shares[i]['percentage'] as num).toDouble();
      final double sweepAngle = (val / totalVal) * 2 * math.pi;

      final paintArc = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - thickness),
        startAngle + 0.05,
        sweepAngle - 0.1,
        false,
        paintArc,
      );

      startAngle += sweepAngle;
    }

    final percentSpan = TextSpan(
      text: '${average.toStringAsFixed(1)}%',
      style: GoogleFonts.outfit(
        color: const Color(0xFF0F172A),
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
      ),
    );
    final percentPainter = TextPainter(text: percentSpan, textDirection: TextDirection.ltr)..layout();
    percentPainter.paint(canvas, center - Offset(percentPainter.width / 2, percentPainter.height));

    final avgSpan = TextSpan(
      text: 'Average\nAttendance',
      style: GoogleFonts.inter(
        color: const Color(0xFF64748B),
        fontSize: 8.5,
        fontWeight: FontWeight.bold,
      ),
    );
    final avgPainter = TextPainter(
      text: avgSpan, 
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    avgPainter.paint(canvas, center + Offset(-avgPainter.width / 2, 4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
