# NoBlurInject – Pure ObjC Runtime dylib (no Logos)
TARGET := iphone:clang:15.6:15.0
ARCHS := arm64e

LIBRARY_NAME := NoBlurInject
NoBlurInject_FILES := Tweak.m
NoBlurInject_CFLAGS := -fobjc-arc -fvisibility=hidden
NoBlurInject_INSTALL_PATH := /usr/lib

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk