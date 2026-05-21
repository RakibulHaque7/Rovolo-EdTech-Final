from django.db import models
from django.conf import settings


class School(models.Model):

    name = models.CharField(
        max_length=255
    )

    address = models.TextField()

    latitude = models.FloatField(
        null=True,
        blank=True
    )

    longitude = models.FloatField(
        null=True,
        blank=True
    )

    allowed_radius = models.PositiveIntegerField(
        default=100,
        help_text="Allowed radius in meters"
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):

        return self.name


class TrainerSchoolAssignment(models.Model):

    trainer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE
    )

    school = models.ForeignKey(
        School,
        on_delete=models.CASCADE
    )

    assigned_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):

        return f"{self.trainer.username} - {self.school.name}"