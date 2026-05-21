from django.contrib import admin
from django.urls import path, include

from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [

    # Admin Panel
    path(
        'admin/',
        admin.site.urls
    ),

    # Users APIs
    path(
        'api/',
        include('apps.users.urls')
    ),

    # Attendance APIs
    path(
        'api/attendance/',
        include('apps.attendance.urls')
    ),

    # Leave APIs
    path(
        'api/leave/',
        include('apps.leave.urls')
    ),

    # Dashboard APIs
    path(
        'api/dashboard/',
        include('apps.dashboard.urls')
    ),

    # Schools APIs
    path(
        'api/schools/',
        include('apps.schools.urls')
    ),

    # JWT Token APIs
    path(
        'api/token/',
        TokenObtainPairView.as_view(),
        name='token_obtain_pair'
    ),

    path(
        'api/token/refresh/',
        TokenRefreshView.as_view(),
        name='token_refresh'
    ),
]

from django.conf import settings
from django.conf.urls.static import static

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)