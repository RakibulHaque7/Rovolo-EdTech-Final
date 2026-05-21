from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .models import (
    School,
    TrainerSchoolAssignment
)

from .serializers import (
    SchoolSerializer,
    TrainerSchoolAssignmentSerializer
)


class CreateSchoolView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = SchoolSerializer(
            data=request.data
        )

        if serializer.is_valid():

            serializer.save()

            return Response({
                "message": "School created successfully",
                "data": serializer.data
            })

        return Response(serializer.errors)


class SchoolListView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request):

        schools = School.objects.all()

        serializer = SchoolSerializer(
            schools,
            many=True
        )

        return Response(serializer.data)


class AssignTrainerView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = (
            TrainerSchoolAssignmentSerializer(
                data=request.data
            )
        )

        if serializer.is_valid():

            serializer.save()

            return Response({
                "message": "Trainer assigned successfully",
                "data": serializer.data
            })

        return Response(serializer.errors)