# Fluor — build interface.
#
# `make` prints the list of targets. Every target is phony.

SHELL := /bin/bash

APP_NAME    := Fluor
BUILD_DIR   := build
DIST_DIR    := dist
RELEASE_DIR := release
SPM_DIR     := .build
INSTALL_DIR ?= $(HOME)/Applications
INSTALL_APP := $(INSTALL_DIR)/$(APP_NAME).app

XCODE_PROJECT := Fluor.xcodeproj
XCODE_SCHEME  := Fluor
XCODE_CONFIG  := Release

# Root of the repository, so every target works from any directory.
ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

DERIVED_DATA := $(ROOT)/$(BUILD_DIR)/DerivedData
DMG_STAGE    := $(ROOT)/$(BUILD_DIR)/dmg-stage

DIST_APP_ARM   := $(ROOT)/$(DIST_DIR)/$(APP_NAME)-arm64.app
DIST_APP_INTEL := $(ROOT)/$(DIST_DIR)/$(APP_NAME)-x86_64.app
DIST_APP_UNIV  := $(ROOT)/$(DIST_DIR)/$(APP_NAME)-universal.app

# The host bundle for install and run, picked by the architecture of this Mac.
HOST_MACHINE := $(shell uname -m)
ifeq ($(HOST_MACHINE),arm64)
HOST_SET      := arm64
HOST_ARCHS    := arm64
DIST_APP_HOST := $(DIST_APP_ARM)
else
HOST_SET      := x86_64
HOST_ARCHS    := x86_64
DIST_APP_HOST := $(DIST_APP_INTEL)
endif

# The version comes from the command line: `make release VERSION=2.8.0`.
VERSION ?=
export VERSION

ifneq ($(strip $(VERSION)),)
VERSION_DIGITS := $(shell printf '%s' '$(VERSION)' | tr -cd '0-9.' | tr -d '.')
ifeq ($(strip $(VERSION_DIGITS)),)
$(error the version "$(VERSION)" holds no digits, so it has no build number)
endif
BUILD_NUMBER  := $(shell echo $$(( $(VERSION_DIGITS) * 10 )))
VERSION_FLAGS := MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(BUILD_NUMBER)
else
VERSION_DIGITS :=
BUILD_NUMBER  :=
VERSION_FLAGS :=
endif

# A disk image carries the version when one is given, so a release writes
# Fluor-<version>-arm64.dmg and Fluor-<version>-x86_64.dmg.
DMG_TAG  := $(if $(strip $(VERSION)),-$(strip $(VERSION)),)
DMG_ARM   := $(ROOT)/$(RELEASE_DIR)/$(APP_NAME)$(DMG_TAG)-arm64.dmg
DMG_INTEL := $(ROOT)/$(RELEASE_DIR)/$(APP_NAME)$(DMG_TAG)-x86_64.dmg
DMG_UNIV  := $(ROOT)/$(RELEASE_DIR)/$(APP_NAME)-universal.dmg

.PHONY: help build test verify run install app app-arm app-intel app-host app-universal \
	dmg dmg-arm dmg-intel dmg-universal release-artifacts release-notes release clean

.DEFAULT_GOAL := help

## help — list every target

help:
	@printf '%s\n' \
		'Fluor — build targets.' \
		'' \
		'  help                 List every target (default).' \
		'  build                Debug build of the SwiftPM package.' \
		'  test                 Run the changelog check and the SwiftPM test suite.' \
		'  verify               Check both bundles: architecture, version and signature.' \
		'  run                  Install the bundle of this Mac into ~/Applications and launch it.' \
		'  install              Copy the bundle of this Mac into ~/Applications.' \
		'  app                  Build both shipping bundles into dist/Fluor-arm64.app and' \
		'                       dist/Fluor-x86_64.app.' \
		'  app-arm              Build the arm64 bundle into dist/Fluor-arm64.app.' \
		'  app-intel            Build the x86_64 bundle into dist/Fluor-x86_64.app.' \
		'  app-host             Build the bundle of this Mac only.' \
		'  app-universal        Build a bundle with both architectures into dist/Fluor-universal.app.' \
		'  dmg                  Build both disk images, Fluor-<version>-arm64.dmg and' \
		'                       Fluor-<version>-x86_64.dmg, under release/.' \
		'  dmg-arm              Build the arm64 disk image from the arm64 bundle.' \
		'  dmg-intel            Build the x86_64 disk image from the x86_64 bundle.' \
		'  dmg-universal        Build release/Fluor-universal.dmg from the universal bundle.' \
		'  release-artifacts    Build both disk images and release/checksums.txt, then verify it.' \
		'  release-notes VERSION=x.y.z  Print the changelog section of a version.' \
		'  release VERSION=x.y.z  Bump the changelog, test, build, verify, commit and tag.' \
		'  clean                Remove .build/, build/, dist/ and release/.' \
		'' \
		'Notes' \
		'  CHANGELOG.md follows the shared shape and `make test` checks it.' \
		'  The app bundle comes from Xcode, not from SwiftPM. Xcode compiles the' \
		'  storyboards, the xib files, the asset catalog and the Icon Composer icon,' \
		'  and the app looks its resources up in the main bundle. `swift build` alone' \
		'  produces a bare executable without resources.' \
		'  Fluor builds one bundle per architecture for Apple silicon (arm64) and for' \
		'  Intel (x86_64): dist/Fluor-arm64.app and dist/Fluor-x86_64.app. A release' \
		'  publishes both disk images with one release/checksums.txt. A disk image' \
		'  carries the version when one is given: make dmg VERSION=2.8.0 writes' \
		'  release/Fluor-2.8.0-arm64.dmg and release/Fluor-2.8.0-x86_64.dmg.' \
		'  Signing stays ad-hoc, as it is today: CODE_SIGN_STYLE = Manual and' \
		'  CODE_SIGN_IDENTITY = "-". There is no Developer ID identity and no' \
		'  notarization.' \
		'  `make release VERSION=2.8.0` moves [Unreleased] to the version, runs the' \
		'  tests, builds and verifies the artifacts, commits the bump and creates the' \
		'  annotated tag. It overrides MARKETING_VERSION without touching' \
		'  Fluor.xcodeproj or Fluor/Info.plist. The build number is the version with' \
		'  the dots removed, times 10: 2.7.0 gives 2700, 2.8.0 gives 2800.' \
		'  create-dmg is required for the dmg targets: brew install create-dmg.'

## build — debug build of the package

build:
	cd "$(ROOT)" && swift build

## test — test suite

test:
	cd "$(ROOT)" && ./scripts/changelog.sh check
	cd "$(ROOT)" && swift test

## verify — check the built bundles

verify:
	@test -d "$(DIST_APP_ARM)" || { \
		echo "error: $(DIST_APP_ARM) is missing. Run make app first."; \
		exit 1; \
	}
	@test -d "$(DIST_APP_INTEL)" || { \
		echo "error: $(DIST_APP_INTEL) is missing. Run make app first."; \
		exit 1; \
	}
	$(call check_bundle,$(DIST_APP_ARM),arm64)
	$(call check_bundle,$(DIST_APP_INTEL),x86_64)
	@echo "Verified $(DIST_APP_ARM) and $(DIST_APP_INTEL)."

## install — copy the bundle of this Mac into ~/Applications

install: app-host
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_APP)"
	ditto "$(DIST_APP_HOST)" "$(INSTALL_APP)"
	@echo "Installed $(INSTALL_APP)"

## run — install the bundle and launch it

run: install
	open "$(INSTALL_APP)"

## app — the two bundles the product ships

app: app-arm app-intel

app-arm:
	$(call build_bundle,arm64,arm64,$(DIST_APP_ARM))

app-intel:
	$(call build_bundle,x86_64,x86_64,$(DIST_APP_INTEL))

app-host:
	$(call build_bundle,$(HOST_SET),$(HOST_ARCHS),$(DIST_APP_HOST))

app-universal:
	$(call build_bundle,universal,arm64 x86_64,$(DIST_APP_UNIV))

## dmg — the two disk images the release publishes

dmg: dmg-arm dmg-intel

dmg-arm: app-arm
	$(call package_dmg,$(DIST_APP_ARM),$(DMG_ARM))

dmg-intel: app-intel
	$(call package_dmg,$(DIST_APP_INTEL),$(DMG_INTEL))

dmg-universal: app-universal
	$(call package_dmg,$(DIST_APP_UNIV),$(DMG_UNIV))

## release-artifacts — the disk images and the checksum file the release publishes

release-artifacts: dmg
	@cd "$(ROOT)/$(RELEASE_DIR)" && rm -f checksums.txt
	@cd "$(ROOT)/$(RELEASE_DIR)" && shasum -a 256 "$(notdir $(DMG_ARM))" "$(notdir $(DMG_INTEL))" > checksums.txt
	@cd "$(ROOT)/$(RELEASE_DIR)" && shasum -a 256 -c checksums.txt
	@echo "$(RELEASE_DIR)/checksums.txt:"
	@cat "$(ROOT)/$(RELEASE_DIR)/checksums.txt"

## release-notes — print the changelog section of a version

release-notes:
	@if [ -z "$(strip $(VERSION))" ]; then \
		echo "error: make release-notes needs a version, for example: make release-notes VERSION=2.8.0"; \
		exit 1; \
	fi
	@./scripts/changelog.sh notes "$(VERSION)"

## release — bump, test, build, verify, commit and tag, without pushing

release:
	@if [ -z "$(strip $(VERSION))" ]; then \
		echo "error: make release needs a version, for example: make release VERSION=2.8.0"; \
		exit 1; \
	fi
	@APP_NAME="$(APP_NAME)" ./scripts/release.sh "$(VERSION)"

## clean — remove everything the build produces

clean:
	rm -rf "$(ROOT)/$(SPM_DIR)" "$(ROOT)/$(BUILD_DIR)" "$(ROOT)/$(DIST_DIR)" "$(ROOT)/$(RELEASE_DIR)"
	@echo "Removed $(SPM_DIR)/, $(BUILD_DIR)/, $(DIST_DIR)/ and $(RELEASE_DIR)/."

# $(1) bundle, $(2) the architecture that bundle must hold
define check_bundle
	@binary="$(1)/Contents/MacOS/$(APP_NAME)"; \
	archs="$$(lipo -archs "$$binary" | tr ' ' '\n' | sort | tr '\n' ' ' | xargs)"; \
	echo "$(1): $$archs"; \
	test "$$archs" = "$(2)" || { \
		echo "error: $(1) should hold $(2), but it holds [$$archs]."; \
		exit 1; \
	}
	@if [ -n "$(strip $(VERSION))" ]; then \
		version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(1)/Contents/Info.plist")"; \
		echo "Bundle version: $$version (expected $(VERSION))"; \
		test "$$version" = "$(VERSION)" || { \
			echo "error: the bundle reports $$version, but $(VERSION) was expected."; \
			exit 1; \
		}; \
	else \
		echo "Bundle version: $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(1)/Contents/Info.plist") (no VERSION given)"; \
	fi
	codesign --verify --deep --strict "$(1)"
endef

# $(1) name of the architecture set, $(2) ARCHS for xcodebuild, $(3) destination bundle
define build_bundle
	@mkdir -p "$(ROOT)/$(DIST_DIR)"
	xcodebuild -project "$(ROOT)/$(XCODE_PROJECT)" -scheme $(XCODE_SCHEME) \
		-configuration $(XCODE_CONFIG) \
		-derivedDataPath "$(DERIVED_DATA)/$(1)" \
		ARCHS="$(2)" ONLY_ACTIVE_ARCH=NO \
		$(VERSION_FLAGS) \
		build
	rm -rf "$(3)"
	ditto "$(DERIVED_DATA)/$(1)/Build/Products/$(XCODE_CONFIG)/$(APP_NAME).app" "$(3)"
	@echo "Built $(3)"
endef

# $(1) bundle to package, $(2) path of the disk image
define package_dmg
	@command -v create-dmg >/dev/null 2>&1 || { \
		echo "error: create-dmg is required to build a disk image."; \
		echo "       install it with: brew install create-dmg"; \
		exit 1; \
	}
	@rm -rf "$(DMG_STAGE)"
	@mkdir -p "$(DMG_STAGE)" "$(ROOT)/$(RELEASE_DIR)"
	ditto "$(1)" "$(DMG_STAGE)/$(APP_NAME).app"
	rm -f "$(2)"
	create-dmg --volname "$(APP_NAME)" --filesystem APFS \
		--window-size 660 400 --icon-size 110 \
		--icon "$(APP_NAME).app" 180 170 --app-drop-link 480 170 \
		"$(2)" "$(DMG_STAGE)"
	@rm -rf "$(DMG_STAGE)"
	@echo "Built $(2)"
endef
