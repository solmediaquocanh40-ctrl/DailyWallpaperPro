TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := DailyWallpaperProPrefs
DailyWallpaperProPrefs_FILES := DWPRootListController.m DWPPhotosController.m DWPLogViewController.m DWPPickerHelper.m ../DWPShared.m
DailyWallpaperProPrefs_FRAMEWORKS := UIKit PhotosUI UniformTypeIdentifiers
DailyWallpaperProPrefs_INSTALL_PATH := /Library/PreferenceBundles
DailyWallpaperProPrefs_CFLAGS := -fobjc-arc -I..
DailyWallpaperProPrefs_LDFLAGS := -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk

# Dong goi entry PreferenceLoader thang vao .deb o khau stage (duong doc lap voi layout/ o goc du an):
# du thu muc layout/ co rot khoi repo khi up thi .deb van chua entry, Cai dat van hien muc DailyWallpaper Pro.
after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"
	@cp entry.plist "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/DailyWallpaperPro.plist" && echo "DailyWallpaperPro: da dong goi entry PreferenceLoader vao .deb" || echo "DailyWallpaperPro: CANH BAO — copy entry that bai, chi con duong layout/"
