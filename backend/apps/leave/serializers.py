from rest_framework import serializers

from .models import LeaveRequest


class LeaveRequestSerializer(serializers.ModelSerializer):

    username = serializers.CharField(
        source='user.username',
        read_only=True
    )

    class Meta:

        model = LeaveRequest

        fields = [

            'id',

            'username',

            'leave_type',

            'reason',

            'start_date',

            'end_date',

            'status',

            'created_at'

        ]

        read_only_fields = [

            'status',

            'created_at'

        ]