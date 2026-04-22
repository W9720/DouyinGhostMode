# DouyinGhostMode - 抖音隐身模式插件

TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DouyinGhostMode

DouyinGhostMode_FILES = Tweak.xm
DouyinGhostMode_CFLAGS = -fobjc-arc
DouyinGhostMode_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 'com.ss.iphone.igaweme' 2>/dev/null || true"
