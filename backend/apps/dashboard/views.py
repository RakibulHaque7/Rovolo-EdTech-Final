from datetime import date

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from apps.attendance.models import Attendance
from apps.leave.models import LeaveRequest

from .serializers import DashboardSerializer


class DashboardSummaryView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request):

        user = request.user
        today = date.today()

        # Today's attendance
        attendance = Attendance.objects.filter(
            user=user,
            date=today
        ).first()

        today_attendance = attendance is not None

        # Default hours
        working_hours_today = "0h 0m"

        # Calculate working hours
        if (
            attendance and
            attendance.check_in_time and
            attendance.check_out_time
        ):

            duration = (
                attendance.check_out_time -
                attendance.check_in_time
            )

            total_seconds = duration.total_seconds()

            hours = int(total_seconds // 3600)
            minutes = int((total_seconds % 3600) // 60)

            working_hours_today = f"{hours}h {minutes}m"

        # Leave stats
        total_leaves = LeaveRequest.objects.filter(
            user=user
        ).count()

        pending_leaves = LeaveRequest.objects.filter(
            user=user,
            status='pending'
        ).count()

        approved_leaves = LeaveRequest.objects.filter(
            user=user,
            status='approved'
        ).count()

        data = {
            "username": user.username,
            "today_attendance": today_attendance,
            "working_hours_today": working_hours_today,
            "total_leaves": total_leaves,
            "pending_leaves": pending_leaves,
            "approved_leaves": approved_leaves
        }

        serializer = DashboardSerializer(data)

        return Response(serializer.data)


class AdminSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Only allow admin / superuser roles to query this view
        if request.user.role != 'admin' and not request.user.is_superuser:
            return Response(
                {"error": "Permission denied. Only admins can query summary statistics."},
                status=status.HTTP_403_FORBIDDEN
            )

        from apps.schools.models import School, TrainerSchoolAssignment
        from apps.users.models import User
        from apps.attendance.models import Attendance
        from datetime import date, timedelta

        # 1. Total Metrics
        total_schools = School.objects.count()
        total_trainers = User.objects.filter(role='trainer').count()
        total_students = User.objects.filter(role='student').count()

        # 2. Today's Attendance Proportions
        today = date.today()
        today_attendance_count = Attendance.objects.filter(
            date=today,
            status='present'
        ).count()

        attendance_percentage = 0.0
        if total_trainers > 0:
            attendance_percentage = round((today_attendance_count / total_trainers) * 100, 2)

        # 3. Recent Class Reports for the latest present attendance records
        recent_attendances = Attendance.objects.filter(
            status='present'
        ).select_related('user').order_by('-created_at')[:4]

        recent_reports = []
        for att in recent_attendances:
            assignment = TrainerSchoolAssignment.objects.filter(trainer=att.user).select_related('school').first()
            school_name = assignment.school.name if assignment else None

            recent_reports.append({
                "trainer": att.user.username.capitalize(),
                "school": school_name or 'Unknown School',
                "class_division": att.class_division or 'N/A',
                "topic": att.topic or 'N/A',
                "date": att.date.strftime('%d %b %Y'),
                "status": att.status.capitalize(),
            })

        # 4. Weekly Attendance Line-Chart Points based on actual present attendance counts
        weekly_stats = []
        for i in range(6, -1, -1):
            day = today - timedelta(days=i)
            count_for_day = Attendance.objects.filter(
                date=day,
                status='present'
            ).count()
            weekly_stats.append({
                "label": day.strftime('%d %b'),
                "value": count_for_day,
            })

        # 5. Attendance percentages by school using assigned trainers and today's attendance
        school_stats = []
        for school in School.objects.all():
            trainer_ids = TrainerSchoolAssignment.objects.filter(
                school=school
            ).values_list('trainer_id', flat=True)
            total_assigned = len(trainer_ids)
            if total_assigned == 0:
                percentage = 0.0
            else:
                present_count = Attendance.objects.filter(
                    user_id__in=trainer_ids,
                    date=today,
                    status='present'
                ).count()
                percentage = round((present_count / total_assigned) * 100, 2)

            school_stats.append({
                "name": school.name,
                "percentage": percentage,
            })

        payload = {
            "total_schools": total_schools,
            "total_trainers": total_trainers,
            "total_students": total_students,
            "today_attendance_count": today_attendance_count,
            "today_attendance_percentage": round(attendance_percentage, 2),
            "recent_class_reports": recent_reports,
            "weekly_overview": weekly_stats,
            "attendance_by_school": school_stats,
        }

        return Response(payload)


class SchoolDashboardSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != 'school':
            return Response(
                {"error": "Permission denied. Only school operators can query this summary."},
                status=status.HTTP_403_FORBIDDEN
            )

        from apps.schools.models import School, TrainerSchoolAssignment
        from apps.leave.models import LeaveRequest
        from apps.attendance.models import Attendance
        from datetime import date

        # 1. Resolve school of logged-in user
        school = School.objects.filter(name__iexact=user.username).first()
        if not school:
            school = School.objects.first()
            if not school:
                school = School.objects.create(
                    name=user.username.replace('_', ' ').title(),
                    address="123 Science Park Road",
                    latitude=28.6139,
                    longitude=77.2090,
                    allowed_radius=100
                )

        # 2. Get assigned trainers
        assignments = TrainerSchoolAssignment.objects.filter(school=school)
        trainers = [a.trainer for a in assignments]

        # 3. Today's metrics
        today = date.today()
        today_attendances = Attendance.objects.filter(user__in=trainers, date=today)
        present_count = today_attendances.filter(status='present').count()
        late_count = today_attendances.filter(status='late').count()
        
        # Approved leaves today
        leaves_today = LeaveRequest.objects.filter(
            user__in=trainers,
            status='approved',
            start_date__lte=today,
            end_date__gte=today
        ).count()

        total_trainers = len(trainers)
        checked_in_count = present_count + late_count
        pending_count = max(0, total_trainers - checked_in_count - leaves_today)

        # 4. Roster with statuses today
        roster = []
        for t in trainers:
            att = today_attendances.filter(user=t).first()
            leave = LeaveRequest.objects.filter(
                user=t,
                status='approved',
                start_date__lte=today,
                end_date__gte=today
            ).first()

            status_text = "Pending Check-In"
            status_color = "0xFF64748B" # Gray
            check_in_time = None
            check_out_time = None
            working_hours = None
            selfie_url = None

            if att:
                if att.status == 'present':
                    status_text = "Checked In"
                    status_color = "0xFF10B981" # Emerald Green
                elif att.status == 'late':
                    status_text = "Checked In (Late)"
                    status_color = "0xFFF59E0B" # Amber Orange
                
                if att.check_in_time:
                    check_in_time = att.check_in_time.strftime('%I:%M %p')
                if att.check_out_time:
                    status_text = "Completed"
                    status_color = "0xFF3B82F6" # Royal Blue
                    check_out_time = att.check_out_time.strftime('%I:%M %p')
                    working_hours = f"{att.working_hours} hrs" if att.working_hours else "--"
                
                selfie_url = request.build_absolute_uri(att.selfie.url) if att.selfie else None
            elif leave:
                status_text = "On Approved Leave"
                status_color = "0xFFF59E0B" # Amber Orange

            roster.append({
                "trainer_id": t.id,
                "name": t.username.replace('_', ' ').title(),
                "email": t.email,
                "status": status_text,
                "color": status_color,
                "check_in_time": check_in_time,
                "check_out_time": check_out_time,
                "working_hours": working_hours,
                "selfie_url": selfie_url
            })

        # 5. Pending leaves approval queue
        pending_leaves = LeaveRequest.objects.filter(
            user__in=trainers,
            status='pending'
        ).order_by('-created_at')

        leaves_queue = []
        for l in pending_leaves:
            leaves_queue.append({
                "id": l.id,
                "trainer_name": l.user.username.replace('_', ' ').title(),
                "leave_type": l.leave_type.replace('_', ' ').title(),
                "reason": l.reason,
                "start_date": l.start_date.strftime('%d %b %Y'),
                "end_date": l.end_date.strftime('%d %b %Y'),
                "status": l.status
            })

        # 6. Detailed Attendance logs
        history_attendances = Attendance.objects.filter(
            user__in=trainers
        ).order_by('-date', '-check_in_time')[:20]

        attendance_logs = []
        for h in history_attendances:
            attendance_logs.append({
                "id": h.id,
                "name": h.user.username.replace('_', ' ').title(),
                "date": h.date.strftime('%d %b %Y'),
                "in": h.check_in_time.strftime('%I:%M %p') if h.check_in_time else "--",
                "out": h.check_out_time.strftime('%I:%M %p') if h.check_out_time else "--",
                "status": "Checked In" if h.status == 'present' else h.status.replace('_', ' ').title(),
                "working_hours": f"{h.working_hours} hrs" if h.working_hours else "--",
                "selfie_url": request.build_absolute_uri(h.selfie.url) if h.selfie else None
            })

        # 7. School Coordinates configuration
        profile = {
            "school_id": school.id,
            "school_name": school.name,
            "address": school.address,
            "latitude": school.latitude,
            "longitude": school.longitude,
            "allowed_radius": school.allowed_radius
        }

        payload = {
            "total_trainers": total_trainers,
            "present_trainers": checked_in_count,
            "absent_trainers": pending_count,
            "leaves_today": leaves_today,
            "attendance_percentage": round((checked_in_count / total_trainers * 100), 1) if total_trainers > 0 else 100.0,
            "roster": roster,
            "leave_queue": leaves_queue,
            "attendance_logs": attendance_logs,
            "profile": profile
        }

        return Response(payload)


class SchoolUpdateGeofenceView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role != 'school':
            return Response(
                {"error": "Permission denied. Only school operators can edit geofencing settings."},
                status=status.HTTP_403_FORBIDDEN
            )

        from apps.schools.models import School

        # Find school
        school = School.objects.filter(name__iexact=user.username).first()
        if not school:
            school = School.objects.first()
            if not school:
                return Response({"error": "No school object found to update."}, status=status.HTTP_404_NOT_FOUND)

        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        radius = request.data.get('allowed_radius')

        if latitude is not None:
            school.latitude = float(latitude)
        if longitude is not None:
            school.longitude = float(longitude)
        if radius is not None:
            school.allowed_radius = int(radius)

        school.save()

        return Response({
            "message": "Geofencing configured successfully.",
            "school": {
                "id": school.id,
                "name": school.name,
                "latitude": school.latitude,
                "longitude": school.longitude,
                "allowed_radius": school.allowed_radius
            }
        })