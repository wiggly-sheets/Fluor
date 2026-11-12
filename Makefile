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

DIST_APP       := $(ROOT)/$(DIST_DIR)/$(APP_NAME).app
DIST_APP_ARM   := $(ROOT)/$(DIST_DIR)/$(APP_NAME)-arm64.app
DIST_APP_INTEL := $(ROOT)/$(DIST_DIR)/$(APP_NAME)-x86_64.app
DIST_APP_UNIV  := $(ROOT)/$(DIST_DIR)/$(APP_NAME)-universal.app

DMG      := $(ROOT)/$(RELEASE_DIR)/$(APP_NAME).dmg
DMG_ARM  := $(ROOT)/$(RELEASE_DIR)/$(APP_NAME)-arm64.dmg
DMG_INTEL := $(ROOT)/$(RELEASE_DIR)/$(APP_NAME)-x86_64.dmg
DMG_UNIV := $(ROOT)/$(RELEASE_DIR)/$(APP_NAME)-universal.dmg

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

.PHONY: help build test verify run install app app-arm app-intel app-universal \
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
		'  verify               Check the bundle: architecture, version and signature.' \
		'  run                  Install the app bundle into ~/Applications and launch it.' \
		'  install              Copy the app bundle into ~/Applications.' \
		'  app                  Build the shipping bundle into dist/Fluor.app.' \
		'  app-arm              Build an arm64 bundle into dist/Fluor-arm64.app.' \
		'  app-intel            Build an x86_64 bundle into dist/Fluor-x86_64.app.' \
		'  app-universal        Build a bundle with both architectures into dist/Fluor-universal.app.' \
		'  dmg                  Build the disk image release/Fluor.dmg from dist/Fluor.app.' \
		'  dmg-arm              Build release/Fluor-arm64.dmg from the arm64 bundle.' \
		'  dmg-intel            Build release/Fluor-x86_64.dmg from the x86_64 bundle.' \
		'  dmg-universal        Build release/Fluor-universal.dmg from the universal bundle.' \
		'  release-artifacts    Build the DMG and release/checksums.txt, then verify the checksum.' \
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
		'  Fluor builds for Apple silicon (arm64) and for Intel (x86_64). The shipping' \
		'  bundle dist/Fluor.app is universal.' \
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

## verify — check the built bundle

verify:
	@test -d "$(DIST_APP)" || { \
		echo "error: $(DIST_APP) is missing. Run make app first."; \
		exit 1; \
	}
	@binary="$(DIST_APP)/Contents/MacOS/$(APP_NAME)"; \
	archs="$$(lipo -archs "$$binary" | tr ' ' '\n' | sort | tr '\n' ' ' | xargs)"; \
	echo "Architectures: $$archs"; \
	test "$$archs" = "arm64 x86_64" || { \
		echo "error: expected a universal binary, got [$$archs]."; \
		exit 1; \
	}
	@if [ -n "$(strip $(VERSION))" ]; then \
		version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(DIST_APP)/Contents/Info.plist")"; \
		echo "Bundle version: $$version (expected $(VERSION))"; \
		test "$$version" = "$(VERSION)" || { \
			echo "error: the bundle reports $$version, but $(VERSION) was expected."; \
			exit 1; \
		}; \
	else \
		echo "Bundle version: $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(DIST_APP)/Contents/Info.plist") (no VERSION given)"; \
	fi
	codesign --verify --deep --strict "$(DIST_APP)"
	@echo "Verified $(DIST_APP)."

## install — copy the bundle into ~/Applications

install: app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_APP)"
	ditto "$(DIST_APP)" "$(INSTALL_APP)"
	@echo "Installed $(INSTALL_APP)"

## run — install the bundle and launch it

run: install
	open "$(INSTALL_APP)"

## app — the bundle the product ships

app:
	$(call build_bundle,universal,arm64 x86_64,$(DIST_APP))

app-arm:
	$(call build_bundle,arm64,arm64,$(DIST_APP_ARM))

app-intel:
	$(call build_bundle,x86_64,x86_64,$(DIST_APP_INTEL))

app-universal:
	$(call build_bundle,universal,arm64 x86_64,$(DIST_APP_UNIV))

## dmg — the disk image

dmg: app
	$(call package_dmg,$(DIST_APP),$(DMG))

dmg-arm: app-arm
	$(call package_dmg,$(DIST_APP_ARM),$(DMG_ARM))

dmg-intel: app-intel
	$(call package_dmg,$(DIST_APP_INTEL),$(DMG_INTEL))

dmg-universal: app-universal
	$(call package_dmg,$(DIST_APP_UNIV),$(DMG_UNIV))

## release-artifacts — the DMG and the sidecar the tap expects

release-artifacts: dmg
	@cd "$(ROOT)/$(RELEASE_DIR)" && shasum -a 256 "$(APP_NAME).dmg" > checksums.txt
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
