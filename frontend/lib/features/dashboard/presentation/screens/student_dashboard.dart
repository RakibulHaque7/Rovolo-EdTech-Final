import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class StudentDashboard extends StatelessWidget {
  final Map<String, dynamic> profile;

  const StudentDashboard({super.key, required this.profile});

  Future<void> _handleLogout(BuildContext context) async {
    await AuthRepository().logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildTaskTile(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: Color(0xFF64748B), size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = profile['username'] as String? ?? 'Student';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0B0F19), // Midnight
              Color(0xFF1E293B), // Deep Blue Space Hue
              Color(0xFF0B0F19),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Welcome Back,',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                                ),
                                child: Text(
                                  'STUDENT',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: const Color(0xFF60A5FA),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            username,
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.logOut, color: Color(0xFFEF4444), size: 24),
                      onPressed: () => _handleLogout(context),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Metrics grid
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.4),
                          border: Border.all(color: const Color(0xFF334155).withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.award, color: Color(0xFFF59E0B), size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Attendance',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '98.2%',
                              style: GoogleFonts.outfit(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.4),
                          border: Border.all(color: const Color(0xFF334155).withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.checkSquare, color: Color(0xFF10B981), size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Tasks Met',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '18 / 20',
                              style: GoogleFonts.outfit(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Active schedule / assignments
                Text(
                  'UPCOMING TASKS & ASSIGNMENTS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                _buildTaskTile('Math Homework #4', 'Due in 2 days - Vector Algebra', LucideIcons.bookOpen, const Color(0xFF3B82F6)),
                const SizedBox(height: 12),
                _buildTaskTile('Weekly Science Quiz', 'Scheduled for Thursday', LucideIcons.compass, const Color(0xFF8B5CF6)),
                const SizedBox(height: 12),
                _buildTaskTile('Attendance Class Register', 'Checked In Today at 09:30 AM', LucideIcons.checkCircle2, const Color(0xFF10B981)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
