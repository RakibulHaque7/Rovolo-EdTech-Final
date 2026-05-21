from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from .models import LeaveRequest
from .serializers import LeaveRequestSerializer


# -----------------------------
# APPLY LEAVE API
# -----------------------------
class ApplyLeaveView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = LeaveRequestSerializer(
            data=request.data
        )

        if serializer.is_valid():

            serializer.save(
                user=request.user
            )

            return Response(
                {
                    "message": "Leave request submitted successfully",
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "message": "Validation failed",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )


# -----------------------------
# LEAVE HISTORY API
# -----------------------------
class LeaveHistoryView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role == 'admin' or request.user.is_superuser:
            leaves = LeaveRequest.objects.all().order_by('-created_at')
        else:
            leaves = LeaveRequest.objects.filter(
                user=request.user
            ).order_by('-created_at')

        serializer = LeaveRequestSerializer(
            leaves,
            many=True
        )

        return Response(
            {
                "message": "Leave history fetched successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )

# -----------------------------
# UPDATE LEAVE STATUS API
# -----------------------------
class UpdateLeaveStatusView(APIView):

    permission_classes = [IsAuthenticated]

    def patch(self, request, leave_id):

        try:

            leave = LeaveRequest.objects.get(
                id=leave_id
            )

        except LeaveRequest.DoesNotExist:

            return Response(
                {
                    "message": "Leave request not found"
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # Get new status from request
        new_status = request.data.get('status')

        # Validate status
        if new_status not in ['approved', 'rejected']:

            return Response(
                {
                    "message": "Invalid status"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update leave status
        leave.status = new_status

        leave.save()

        serializer = LeaveRequestSerializer(leave)

        return Response(
            {
                "message": "Leave status updated successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )