from rest_framework import serializers
from apps.users.models import User


class RegisterSerializer(serializers.ModelSerializer):

    password = serializers.CharField(write_only=True)

    class Meta:
        model = User

        fields = [
            'username',
            'email',
            'password',
            'role',
            'phone_number',
        ]

    def create(self, validated_data):

        password = validated_data.pop('password')

        user = User(**validated_data)

        user.set_password(password)

        user.save()

        return user


class UserSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()

    class Meta:
        model = User

        fields = [
            'id',
            'username',
            'email',
            'role',
            'phone_number',
            'is_verified',
            'created_at',
        ]

    def get_role(self, obj):
        if obj.is_superuser:
            return 'admin'
        return obj.role