from rest_framework import serializers

from .models import User


class RegisterSerializer(serializers.ModelSerializer):

    password = serializers.CharField(write_only=True)

    class Meta:

        model = User

        fields = (
            'id',
            'username',
            'email',
            'password',
            'role',
        )

    def validate_role(self, value):
        if value == 'admin':
            raise serializers.ValidationError("Public signup is not allowed for Admin roles.")
        return value

    def create(self, validated_data):

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            role=validated_data['role'],
        )

        return user


class UserSerializer(serializers.ModelSerializer):

    assigned_school = serializers.SerializerMethodField()
    role = serializers.SerializerMethodField()

    class Meta:

        model = User

        fields = (
            'id',
            'username',
            'email',
            'role',
            'assigned_school',
        )

    def get_role(self, obj):
        if obj.is_superuser:
            return 'admin'
        return obj.role

    def get_assigned_school(self, obj):
        from apps.schools.models import TrainerSchoolAssignment, School
        if obj.role == 'trainer':
            assignment = TrainerSchoolAssignment.objects.filter(
                trainer=obj
            ).first()
            if assignment:
                school = assignment.school
                return {
                    'id': school.id,
                    'name': school.name,
                    'latitude': school.latitude,
                    'longitude': school.longitude,
                    'allowed_radius': school.allowed_radius,
                }
        elif obj.role == 'school':
            # Try to find a school by username
            school = School.objects.filter(name__iexact=obj.username).first()
            if not school:
                # Find the first school or create a dynamic one
                school = School.objects.first()
                if not school:
                    school = School.objects.create(
                        name=obj.username.replace('_', ' ').title(),
                        address="123 Science Park Road",
                        latitude=28.6139,
                        longitude=77.2090,
                        allowed_radius=100
                    )
            return {
                'id': school.id,
                'name': school.name,
                'latitude': school.latitude,
                'longitude': school.longitude,
                'allowed_radius': school.allowed_radius,
            }
        return None