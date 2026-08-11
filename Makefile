# NoBlurInject - Universal Blur Disabler for TrollStore/TrollFools
# 编译目标: iOS 15.6 SDK, arm64e (A12+), 向下兼容 iOS 15.0

# 强制锁定 SDK 版本，防止被环境变量或其他 makefile 覆盖
SDKVERSION := 15.6
TARGET := iphone:clang:$(SDKVERSION):15.0

ARCHS := arm64e
TWEAK_NAME := NoBlurInject

NoBlurInject_FILES := Tweak.x
NoBlurInject_CFLAGS := -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk