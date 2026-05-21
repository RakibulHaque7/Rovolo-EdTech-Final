from geopy.distance import geodesic


def is_within_allowed_radius(
    school_lat,
    school_long,
    allowed_radius,
    employee_lat,
    employee_long
):
    """
    Validate whether employee is within
    school's allowed GPS radius
    """

    school_location = (
        school_lat,
        school_long
    )

    employee_location = (
        employee_lat,
        employee_long
    )

    distance = geodesic(
        school_location,
        employee_location
    ).meters

    is_allowed = distance <= allowed_radius

    return is_allowed, round(distance, 2)