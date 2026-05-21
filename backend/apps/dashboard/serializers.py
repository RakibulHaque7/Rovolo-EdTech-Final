from rest_framework import serializers

class DashboardSerializer(serializers.Serializer):
    username = serializers.CharField()
    today_attendance = serializers.BooleanField()
    working_hours_today = serializers.CharField()
    total_leaves = serializers.IntegerField()
    pending_leaves = serializers.IntegerField()
    approved_leaves = serializers.IntegerField()