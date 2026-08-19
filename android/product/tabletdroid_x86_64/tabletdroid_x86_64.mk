# TabletDroid AOSP Product Makefile (x86_64 Tablet)

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_x86_64.mk)

PRODUCT_NAME := tabletdroid_x86_64
PRODUCT_DEVICE := generic_x86_64
PRODUCT_BRAND := TabletDroid
PRODUCT_MODEL := TabletDroid Virtual Tablet
PRODUCT_MANUFACTURER := TabletDroid Project

# 1920x1200 Tablet 특화 속성
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=280 \
    ro.build.characteristics=tablet \
    persist.sys.app.rotation=auto

# 불필요한 Telephony / Cellular 제거
PRODUCT_PACKAGES += \
    TabletDroidGuestAgent \
    TabletDroidOverlay

PRODUCT_PACKAGE_OVERLAYS += \
    android/overlays
