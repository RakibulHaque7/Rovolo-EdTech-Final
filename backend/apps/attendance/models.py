from django.db import models

from apps.users.models import User


class Attendance(models.Model):

    STATUS_CHOICES = (

        ('present', 'Present'),
        ('absent', 'Absent'),
        ('late', 'Late'),

    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='attendances'
    )

    date = models.DateField(
        auto_now_add=True
    )

    check_in_time = models.DateTimeField(
        null=True,
        blank=True
    )

    check_out_time = models.DateTimeField(
        null=True,
        blank=True
    )

    working_hours = models.FloatField(
        null=True,
        blank=True
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='present'
    )

    selfie = models.ImageField(
        upload_to='attendance_selfies/',
        null=True,
        blank=True
    )

    class_division = models.CharField(
        max_length=100,
        null=True,
        blank=True
    )

    topic = models.CharField(
        max_length=255,
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):

        return f"{self.user.username} - {self.date}"