# ============================================================
# NoBlurInject — Universal Blur Blocker dylib
# Builds as a rootless, bundle-free tweak (filter = Any)
# Architectures: arm64 + arm64e → merged via lipo
# ============================================================

# Auto-detect THEOS if not set
THEOS ?= $(shell ls -d /home/linuxbrew/.linuxbrew/share/theos 2>/dev/null \
              || ls -d /opt/homebrew/share/theos 2>/dev/null \
              || ls -d /usr/local/share/theos 2>/dev/null \
              || ls -d $$HOME/theos 2>/dev/null \
              || echo "$$HOME/theos")

# Allow ARCHS override from command line:  make ARCHS=arm64e
ARCHS ?= arm64 arm64e

# Target: iOS 14.0 SDK, deployment 14.0
TARGET ?= iphone:clang:15.0:14.0

TWEAK_NAME = NoBlurInject
$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -O2
$(TWEAK_NAME)_LDFLAGS = -framework UIKit -framework Foundation

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

# ─── Post-build: merge archs into universal dylib ────────
# Only runs if both arm64 + arm64e were built (or user requested both)
PACKAGES_DIR = $(THEOS_PROJECT_DIR)/packages

internal-after-install::
	@echo ""
	@echo "→ Checking for multi-arch merge..."
	@mkdir -p $(PACKAGES_DIR)
	@if [ -f "$(THEOS_OBJ_DIR)/arm64/$(TWEAK_NAME).dylib" ] && \
	   [ -f "$(THEOS_OBJ_DIR)/arm64e/$(TWEAK_NAME).dylib" ]; then \
		echo "→ Merging arm64 + arm64e → universal dylib..."; \
		lipo -create \
			"$(THEOS_OBJ_DIR)/arm64/$(TWEAK_NAME).dylib" \
			"$(THEOS_OBJ_DIR)/arm64e/$(TWEAK_NAME).dylib" \
			-output $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib; \
		echo "✅ Universal dylib → $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib"; \
		lipo -info $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib; \
	elif [ -f "$(THEOS_OBJ_DIR)/arm64/$(TWEAK_NAME).dylib" ]; then \
		cp "$(THEOS_OBJ_DIR)/arm64/$(TWEAK_NAME).dylib" \
		   $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib; \
		echo "✅ Single-arch (arm64) dylib → $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib"; \
	elif [ -f "$(THEOS_OBJ_DIR)/arm64e/$(TWEAK_NAME).dylib" ]; then \
		cp "$(THEOS_OBJ_DIR)/arm64e/$(TWEAK_NAME).dylib" \
		   $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib; \
		echo "✅ Single-arch (arm64e) dylib → $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib"; \
	else \
		echo "⚠️ No dylib found in $(THEOS_OBJ_DIR)/"; \
		echo "  Check THEOS=$(THEOS)"; \
		find .theos -name "*.dylib" 2>/dev/null || true; \
	fi
	@echo ""
	@echo "📦 Final artifact: $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib"
	@ls -lh $(PACKAGES_DIR)/$(TWEAK_NAME)-universal.dylib 2>/dev/null || true

# Clean target
clean::
	@rm -rf $(THEOS_OBJ_DIR) $(PACKAGES_DIR)
	@echo "🧹 Cleaned"
