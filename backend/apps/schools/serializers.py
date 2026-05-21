from rest_framework import serializers

from .models import (
    School,
    TrainerSchoolAssignment
)


class SchoolSerializer(serializers.ModelSerializer):

    class Meta:

        model = School

        fields = '__all__'


class TrainerSchoolAssignmentSerializer(
    serializers.ModelSerializer
):

    class Meta:

        model = TrainerSchoolAssignment

        fields = '__all__'