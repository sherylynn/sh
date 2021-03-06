#
# Copyright 2015-2016 Preetam J. D'Souza
# Copyright 2016 The Maru OS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# -----------------------------------------------------------------------------
# Include LineageOS stuff

$(call inherit-product, device/xiaomi/raphael/lineage_raphael.mk)

# -----------------------------------------------------------------------------
# Lineage's sepolicy must be explicitly added for non "lineage_*" products
# $(call inherit-product, vendor/cm/sepolicy/sepolicy.mk)
# ----------------------------------------------------------
# Include Maru stuff
$(call inherit-product, vendor/maruos/device-maru.mk)
$(call inherit-product, vendor/maruos/BoardConfigVendor.mk)

#WITH_DEXPREOPT := false
PRODUCT_NAME := maru_raphael
PRODUCT_DEVICE := raphael
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := Redmi K20 Pro
PRODUCT_MANUFACTURER := Xiaomi

MARU_VERSION := 0.7-test
MARU_BUILD_VERSION := $(MARU_VERSION)-$(shell date -u +%Y%m%d)

DEVICE_PACKAGE_OVERPLAYS += \
														device/xiaomi/raphael/overlay_maru/daydream
