from django.contrib import admin
from .models import Attendance

@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = ('user', 'date', 'check_in_time', 'check_out_time', 'working_hours', 'status', 'selfie')
    search_fields = ('user__username', 'status')
    list_filter = ('date', 'status')
