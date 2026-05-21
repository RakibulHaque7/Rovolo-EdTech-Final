from rest_framework.permissions import BasePermission


class IsAdmin(BasePermission):

    def has_permission(self, request, view):
        return request.user.role == "admin"


class IsTrainer(BasePermission):

    def has_permission(self, request, view):
        return request.user.role == "trainer"


class IsSchool(BasePermission):

    def has_permission(self, request, view):
        return request.user.role == "school"


class IsStudent(BasePermission):

    def has_permission(self, request, view):
        return request.user.role == "student"