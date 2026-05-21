from django.urls import path

from .views import (
    CreateSchoolView,
    SchoolListView,
    AssignTrainerView
)

urlpatterns = [

    path(
        'create/',
        CreateSchoolView.as_view(),
        name='create-school'
    ),

    path(
        'list/',
        SchoolListView.as_view(),
        name='school-list'
    ),

    path(
        'assign-trainer/',
        AssignTrainerView.as_view(),
        name='assign-trainer'
    ),
]