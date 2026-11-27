TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := DailyWallpaperPro
DailyWallpaperPro_FILES := Tweak.x DWPEngine.m DWPShared.m
DailyWallpaperPro_FRAMEWORKS := UIKit Foundation CoreFoundation
DailyWallpaperPro_CFLAGS := -fobjc-arc

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
