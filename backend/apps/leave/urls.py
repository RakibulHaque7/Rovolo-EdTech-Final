from django.urls import path

from .views import (
    ApplyLeaveView,
    LeaveHistoryView,
    UpdateLeaveStatusView
)

urlpatterns = [

    # Apply Leave
    path(
        'apply/',
        ApplyLeaveView.as_view(),
        name='apply-leave'
    ),

    # Leave History
    path(
        'history/',
        LeaveHistoryView.as_view(),
        name='leave-history'
    ),

    # Approve / Reject Leave
    path(
        'update-status/<int:leave_id>/',
        UpdateLeaveStatusView.as_view(),
        name='update-leave-status'
    ),

]