"""Client requirements inferred from the signed, data-only policy profiles."""

PROFILES = {
    "damage_forecast_profile": ("legacy-v1", "reviewed-gust-v1"),
    "plan_comparison_profile": ("legacy-v1", "resource-continuity-v1", "resource-continuity-v2", "card-goals-v1"),
}


def requirements(adapter):
    required = []
    for field, profiles in PROFILES.items():
        value = adapter.get(field, "legacy-v1")
        if type(value) is not str or value not in profiles:
            raise ValueError("package_runtime_profile_unknown")
        if value != "legacy-v1":
            required.append(field + ":" + value)
    return ({"minimum_client_version": "0.6.3", "minimum_client_build": 63,
             "required_profiles": required} if required else {})
