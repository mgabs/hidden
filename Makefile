# Hidden Bar local build & test shortcuts (direct build, unsigned by default).
# Override variables as needed, e.g.: make build SIGNING=""

PROJECT := HiddenBar.xcodeproj
SCHEME := Hidden Bar
DERIVED_DATA := build
APP_NAME := Hidden Bar.app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release-Direct/$(APP_NAME)
SIGNING := CODE_SIGNING_ALLOWED=NO

.DEFAULT_GOAL := help
.PHONY: help build test install open clean

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build Release-Direct app into build/
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release-Direct -derivedDataPath "$(DERIVED_DATA)" -destination "platform=macOS" $(SIGNING) build
	@if [ -n "$(SIGNING)" ]; then codesign --force --deep --sign - "$(RELEASE_APP)"; fi
	@echo "Built: $(RELEASE_APP)"

test: ## Run Debug-Direct unit tests
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug-Direct -derivedDataPath "$(DERIVED_DATA)" -destination "platform=macOS" $(SIGNING) test

install: build ## Build and install app to /Applications
	rm -rf "/Applications/$(APP_NAME)"
	cp -R "$(RELEASE_APP)" "/Applications/$(APP_NAME)"
	@echo "Installed: /Applications/$(APP_NAME)"

open: build ## Build and launch the app
	open "$(RELEASE_APP)"

clean: ## Remove local build artifacts
	rm -rf "$(DERIVED_DATA)"
