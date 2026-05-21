from django.contrib import admin
from .models import School, TrainerSchoolAssignment

@admin.register(School)
class SchoolAdmin(admin.ModelAdmin):
    list_display = ('name', 'address', 'latitude', 'longitude', 'allowed_radius', 'created_at')
    search_fields = ('name', 'address')
    list_filter = ('created_at',)

@admin.register(TrainerSchoolAssignment)
class TrainerSchoolAssignmentAdmin(admin.ModelAdmin):
    list_display = ('trainer', 'school', 'assigned_at')
    search_fields = ('trainer__username', 'school__name')
    list_filter = ('assigned_at',)
