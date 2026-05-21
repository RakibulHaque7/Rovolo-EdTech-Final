from rest_framework import serializers

from apps.attendance.models import Attendance


class AttendanceSerializer(serializers.ModelSerializer):

    # Show username instead of user ID
    username = serializers.CharField(
        source='user.username',
        read_only=True
    )

    # Custom calculated field
    working_hours = serializers.SerializerMethodField()

    class Meta:

        model = Attendance

        fields = [

            'id',

            'username',

            'date',

            'check_in_time',

            'check_out_time',

            'working_hours',

            'status',

            'created_at',

            'updated_at'

        ]

    # Calculate working hours
    def get_working_hours(self, obj):

        if obj.check_in_time and obj.check_out_time:

            duration = obj.check_out_time - obj.check_in_time

            total_seconds = int(duration.total_seconds())

            hours = total_seconds // 3600

            minutes = (total_seconds % 3600) // 60

            return f"{hours}h {minutes}m"

        return None