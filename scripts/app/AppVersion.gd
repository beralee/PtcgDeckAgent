extends RefCounted

const VERSION := "0.5.2"
const DISPLAY_VERSION := "v0.5.2"
const BUILD_NUMBER := 52
const WEB_VERSION := "0.5.2.6"
const WEB_DISPLAY_VERSION := "v0.5.2.6"
const WEB_BUILD_NUMBER := 526
const CHANNEL := "stable"


static func current_version() -> String:
	return WEB_VERSION if OS.has_feature("web") else VERSION


static func current_display_version() -> String:
	return WEB_DISPLAY_VERSION if OS.has_feature("web") else DISPLAY_VERSION


static func current_build_number() -> int:
	return WEB_BUILD_NUMBER if OS.has_feature("web") else BUILD_NUMBER
