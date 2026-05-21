from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .serializers import (
    RegisterSerializer,
    UserSerializer
)

from apps.users.models import User

from apps.users.permissions import (
    IsAdmin,
    IsTrainer,
    IsSchool,
    IsStudent
)


class RegisterView(generics.CreateAPIView):

    queryset = User.objects.all()

    serializer_class = RegisterSerializer


class MeView(generics.RetrieveAPIView):

    serializer_class = UserSerializer

    permission_classes = [IsAuthenticated]

    def get_object(self):

        return self.request.user


class AdminDashboardView(APIView):

    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):

        data = {
            "message": "Welcome Admin",
            "user": request.user.username,
            "role": request.user.role,
        }

        return Response(data)

class UserListView(APIView):

    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        role = request.query_params.get('role')
        if role:
            users = User.objects.filter(role=role)
        else:
            users = User.objects.all()

        serializer = UserSerializer(users, many=True)
        return Response(serializer.data)


class TrainerListView(APIView):

    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        trainers = User.objects.filter(role='trainer')
        serializer = UserSerializer(trainers, many=True)
        return Response(serializer.data)

class TrainerDashboardView(APIView):

    permission_classes = [IsAuthenticated, IsTrainer]

    def get(self, request):

        data = {
            "message": "Welcome Trainer",
            "user": request.user.username,
            "role": request.user.role,
        }

        return Response(data)


class SchoolDashboardView(APIView):

    permission_classes = [IsAuthenticated, IsSchool]

    def get(self, request):

        data = {
            "message": "Welcome School",
            "user": request.user.username,
            "role": request.user.role,
        }

        return Response(data)


class StudentDashboardView(APIView):

    permission_classes = [IsAuthenticated, IsStudent]

    def get(self, request):

        data = {
            "message": "Welcome Student",
            "user": request.user.username,
            "role": request.user.role,
        }

        return Response(data)