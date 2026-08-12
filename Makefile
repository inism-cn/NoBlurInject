# NoBlurInject - Pure ObjC Runtime dylib (no Logos, no deb package)
TARGET := iphone:clang:14.5:14.0
ARCHS := arm64e

LIBRARY_NAME := NoBlurInject
NoBlurInject_FILES := Tweak.m
NoBlurInject_CFLAGS := -fobjc-arc -fvisibility=hidden
NoBlurInject_INSTALL_PATH := /usr/lib

# 关键：只编译，不打包 deb
# 用 'make all' 代替 'make package'

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk

# 覆盖 package 目标，使其变成 no-op，防止误调用
package:
	@echo "==> Skipping deb package (dylib only)"

after-install::
	@echo "==> dylib built, no install step needed"