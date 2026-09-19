extends RefCounted

const VERSION := "0.6.0"
const DISPLAY_VERSION := "v0.6.0"
const BUILD_NUMBER := 60
const WEB_VERSION := "0.6.0.2"
const WEB_DISPLAY_VERSION := "v0.6.0.2"
const WEB_BUILD_NUMBER := 602
const CHANNEL := "stable"


static func current_version() -> String:
	return WEB_VERSION if OS.has_feature("web") else VERSION


static func current_display_version() -> String:
	return WEB_DISPLAY_VERSION if OS.has_feature("web") else DISPLAY_VERSION


static func current_build_number() -> int:
	return WEB_BUILD_NUMBER if OS.has_feature("web") else BUILD_NUMBER
