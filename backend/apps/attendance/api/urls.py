from django.urls import path

from .views import (
    CheckInView,
    CheckOutView,
    AttendanceHistoryView,

    today_attendance_report,
    dashboard_summary,
    monthly_analytics
)

urlpatterns = [

    # =====================================
    # ATTENDANCE APIs
    # =====================================

    # Check In API
    path(
        'check-in/',
        CheckInView.as_view(),
        name='check-in'
    ),

    # Check Out API
    path(
        'check-out/',
        CheckOutView.as_view(),
        name='check-out'
    ),

    # Attendance History API
    path(
        'history/',
        AttendanceHistoryView.as_view(),
        name='attendance-history'
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