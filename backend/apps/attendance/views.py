from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from rest_framework.decorators import api_view, permission_classes

from django.utils import timezone
from django.contrib.auth import get_user_model

from datetime import date
import calendar

from .models import Attendance
from .serializers import AttendanceSerializer

from .gps_utils import is_within_allowed_radius

from apps.schools.models import TrainerSchoolAssignment


User = get_user_model()


class CheckInView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        # Get employee GPS coordinates and selfie photo
        employee_lat = request.data.get("latitude")
        employee_long = request.data.get("longitude")
        selfie_file = request.FILES.get("selfie")

        # Validate GPS data exists
        if not employee_lat or not employee_long:

            return Response(
                {
                    "error": "Latitude and longitude are required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Require selfie for trainer roles
        if request.user.role == 'trainer' and not selfie_file:

            return Response(
                {
                    "error": "Selfie verification photo is required to check in"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Convert GPS values to float
        employee_lat = float(employee_lat)
        employee_long = float(employee_long)

        # Get trainer's assigned school
        trainer_assignment = TrainerSchoolAssignment.objects.filter(
            trainer=request.user
        ).first()

        # Check if school assigned
        if not trainer_assignment:

            return Response(
                {
                    "error": "No school assigned"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get school
        school = trainer_assignment.school

        # Validate school GPS exists
        if (
            school.latitude is None or
            school.longitude is None
        ):

            return Response(
                {
                    "error": "School GPS not configured"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validate GPS radius
        is_allowed, distance = is_within_allowed_radius(
            school.latitude,
            school.longitude,
            school.allowed_radius,
            employee_lat,
            employee_long
        )

        # Reject if outside radius
        if not is_allowed:

            return Response(
                {
                    "error": "You are outside school radius",
                    "distance_in_meters": distance
                },
                status=status.HTTP_403_FORBIDDEN
            )

        today = timezone.now().date()

        # Prevent multiple check-ins
        attendance_exists = Attendance.objects.filter(
            user=request.user,
            date=today
        ).exists()

        if attendance_exists:

            return Response(
                {
                    "message": "You already checked in today."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Take optional class metadata from request for reporting
        class_division = request.data.get('class_division')
        topic = request.data.get('topic')

        # Create attendance with selfie and optional report metadata
        attendance = Attendance.objects.create(
            user=request.user,
            date=today,
            check_in_time=timezone.now(),
            status='present',
            selfie=selfie_file,
            class_division=class_division,
            topic=topic,
        )

        serializer = AttendanceSerializer(attendance)

        return Response(
            {
                "message": "Check-in successful",
                "distance_in_meters": distance,
                "data": serializer.data
            },
            status=status.HTTP_201_CREATED
        )


class CheckOutView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        # Get employee GPS coordinates
        employee_lat = request.data.get("latitude")
        employee_long = request.data.get("longitude")

        # Validate GPS data exists
        if not employee_lat or not employee_long:

            return Response(
                {
                    "error": "Latitude and longitude are required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Convert GPS values to float
        employee_lat = float(employee_lat)
        employee_long = float(employee_long)

        # Get trainer's assigned school
        trainer_assignment = TrainerSchoolAssignment.objects.filter(
            trainer=request.user
        ).first()

        # Check if school assigned
        if not trainer_assignment:

            return Response(
                {
                    "error": "No school assigned"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get school
        school = trainer_assignment.school

        # Validate school GPS exists
        if (
            school.latitude is None or
            school.longitude is None
        ):

            return Response(
                {
                    "error": "School GPS not configured"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validate GPS radius
        is_allowed, distance = is_within_allowed_radius(
            school.latitude,
            school.longitude,
            school.allowed_radius,
            employee_lat,
            employee_long
        )

        # Reject if outside radius
        if not is_allowed:

            return Response(
                {
                    "error": "You are outside school radius",
                    "distance_in_meters": distance
                },
                status=status.HTTP_403_FORBIDDEN
            )

        today = timezone.now().date()

        # Find today's attendance
        attendance = Attendance.objects.filter(
            user=request.user,
            date=today
        ).first()

        # If no check-in exists
        if not attendance:

            return Response(
                {
                    "error": "No check-in found for today"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Prevent multiple check-outs
        if attendance.check_out_time:

            return Response(
                {
                    "error": "Already checked out today"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Save checkout time
        attendance.check_out_time = timezone.now()

        # Calculate working hours
        working_duration = (
            attendance.check_out_time -
            attendance.check_in_time
        )

        attendance.working_hours = round(
            working_duration.total_seconds() / 3600,
            2
        )

        attendance.save()

        serializer = AttendanceSerializer(attendance)

        return Response(
            {
                "message": "Check-out successful",
                "working_hours": attendance.working_hours,
                "distance_in_meters": distance,
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )


class AttendanceHistoryView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role == 'admin' or request.user.is_superuser:
            attendances = Attendance.objects.all().order_by('-date')
        else:
            attendances = Attendance.objects.filter(
                user=request.user
            ).order_by('-date')

        serializer = AttendanceSerializer(
            attendances,
            many=True
        )

        return Response(
            {
                "message": "Attendance history fetched successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )


# =========================================
# TODAY ATTENDANCE REPORT
# =========================================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def today_attendance_report(request):

    today = date.today()

    total_employees = User.objects.count()

    today_attendance = Attendance.objects.filter(
        date=today
    )

    present_today = today_attendance.count()

    checked_out = today_attendance.filter(
        check_out_time__isnull=False
    ).count()

    absent_today = total_employees - present_today

    data = {
        "date": today,
        "total_employees": total_employees,
        "present_today": present_today,
        "checked_out": checked_out,
        "absent_today": absent_today
    }

    return Response(data)


# =========================================
# EMPLOYEE ATTENDANCE HISTORY
# =========================================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def employee_attendance_history(request, user_id):

    attendance_records = Attendance.objects.filter(
        user_id=user_id
    ).order_by('-date')

    data = []

    for record in attendance_records:

        data.append({
            "date": record.date,
            "check_in_time": record.check_in_time,
            "check_out_time": record.check_out_time,
            "working_hours": record.working_hours,
            "status": record.status
        })

    return Response(data)


# =========================================
# DASHBOARD SUMMARY
# =========================================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_summary(request):

    today = date.today()

    total_employees = User.objects.count()

    present_today = Attendance.objects.filter(
        date=today
    ).count()

    absent_today = total_employees - present_today

    data = {
        "total_employees": total_employees,
        "present_today": present_today,
        "absent_today": absent_today
    }

    return Response(data)


# =========================================
# MONTHLY ANALYTICS
# =========================================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def monthly_analytics(request):

    today = date.today()

    current_month = today.month
    current_year = today.year

    total_working_days = calendar.monthrange(
        current_year,
        current_month
    )[1]

    present_days = Attendance.objects.filter(
        date__month=current_month,
        date__year=current_year
    ).count()

    absent_days = total_working_days - present_days

    data = {
        "month": current_month,
        "year": current_year,
        "total_working_days": total_working_days,
        "present_days": present_days,
        "absent_days": absent_days
    }

    return Response(data)