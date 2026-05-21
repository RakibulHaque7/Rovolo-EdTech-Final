from django.urls import path

from .views import (

    # Attendance APIs
    CheckInView,
    CheckOutView,
    AttendanceHistoryView,

    # Report APIs
    today_attendance_report,
    employee_attendance_history,
    dashboard_summary,
    monthly_analytics
)


urlpatterns = [

    # =====================================
    # ATTENDANCE APIs
    # =====================================

    path(
        'check-in/',
        CheckInView.as_view(),
        name='check-in'
    ),

    path(
        'check-out/',
        CheckOutView.as_view(),
        name='check-out'
    ),


    # =====================================
    # REPORT APIs
    # =====================================

    # Today's attendance report
    path(
        'reports/today/',
        today_attendance_report,
        name='today-attendance-report'
    ),

    # Employee attendance history
    path(
        'history/<int:user_id>/',
        employee_attendance_history,
        name='employee-attendance-history'
    ),

    # Admin / personal attendance history
    path(
        'history/',
        AttendanceHistoryView.as_view(),
        name='attendance-history'
    ),

    # Dashboard summary
    path(
        'dashboard-summary/',
        dashboard_summary,
        name='dashboard-summary'
    ),

    # Monthly analytics
    path(
        'reports/monthly/',
        monthly_analytics,
        name='monthly-analytics'
    ),
]