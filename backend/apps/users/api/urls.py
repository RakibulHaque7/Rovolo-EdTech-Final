from django.urls import path

from .views import (
    RegisterView,
    MeView,
    AdminDashboardView,
    TrainerDashboardView,
    SchoolDashboardView,
    StudentDashboardView,
)

urlpatterns = [

    path(
        'register/',
        RegisterView.as_view(),
        name='register'
    ),

    path(
        'me/',
        MeView.as_view(),
        name='me'
    ),

    path(
        'admin-dashboard/',
        AdminDashboardView.as_view(),
        name='admin-dashboard'
    ),

    path(
        'trainer-dashboard/',
        TrainerDashboardView.as_view(),
        name='trainer-dashboard'
    ),

    path(
        'school-dashboard/',
        SchoolDashboardView.as_view(),
        name='school-dashboard'
    ),

    path(
        'student-dashboard/',
        StudentDashboardView.as_view(),
        name='student-dashboard'
    ),
]