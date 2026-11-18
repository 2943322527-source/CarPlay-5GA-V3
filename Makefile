# This package complements the working experimental V1 bridge.
# It does not replace FakeSignalBar or modify system files.
TARGET := iphone:clang:latest:16.0
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = roothide
DEB_ARCH = iphoneos-arm64e
INSTALL_TARGET_PROCESSES = CarPlay

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CarPlay5GAWidthFix
CarPlay5GAWidthFix_FILES = Tweak.xm
CarPlay5GAWidthFix_CFLAGS = -fobjc-arc -Wall -Wextra
CarPlay5GAWidthFix_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
