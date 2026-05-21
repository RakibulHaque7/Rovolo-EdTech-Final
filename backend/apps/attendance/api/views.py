from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from rest_framework.decorators import api_view, permission_classes

from django.utils import timezone
from django.contrib.auth import get_user_model

from datetime import date
import calendar

from apps.attendance.models import Attendance
from .serializers import AttendanceSerializer


User = get_user_model()


# -----------------------------
# CHECK-IN API
# -----------------------------
class CheckInView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        today = timezone.now().date()

        # Check if already checked in today
        attendance_exists = Attendance.objects.filter(
            user=request.user,
            date=today
        ).exists()

        if attendance_exists:

            return Response(
                {
                    "message": "Already checked in today"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create attendance record
        attendance = Attendance.objects.create(

            user=request.user,

            date=today,

            check_in_time=timezone.now(),

            status='present'
        )

        serializer = AttendanceSerializer(attendance)

        return Response(

            {
                "message": "Check-in successful",

                "data": serializer.data
            },

            status=status.HTTP_201_CREATED
        )


# -----------------------------
# CHECK-OUT API
# -----------------------------
class CheckOutView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        today = timezone.now().date()

        # Find today's attendance record
        attendance = Attendance.objects.filter(
            user=request.user,
            date=today
        ).first()

        # No check-in found
        if not attendance:

            return Response(
                {
                    "message": "No check-in found for today"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Prevent double checkout
        if attendance.check_out_time:

            return Response(
                {
                    "message": "Already checked out today"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update checkout time
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

                "data": serializer.data
            },

            status=status.HTTP_200_OK
        )


# -----------------------------
# ATTENDANCE HISTORY API
# -----------------------------
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


# -----------------------------
# TODAY ATTENDANCE REPORT API
# -----------------------------
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


# -----------------------------
# DASHBOARD SUMMARY API
# -----------------------------
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


# -----------------------------
# MONTHLY ANALYTICS API
# -----------------------------
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