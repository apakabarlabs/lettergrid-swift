SWIFT_SOURCES = Sources Tests Package.swift

.DEFAULT_GOAL := build

.PHONY: install-tools format lint comments test-build test build levels

install-tools:
	brew install swiftlint swift-format
	python3 -m pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git

format:
	swift-format format --in-place --recursive $(SWIFT_SOURCES)

comments:
	commentcensor .

lint: comments
	swift-format lint --strict --recursive $(SWIFT_SOURCES)
	swiftlint --strict

test-build:
	swift build --build-tests

test:
	swift test $(if $(TEST),--filter '$(TEST)',)

build: lint test
	swift build

levels:
	@test -n '$(CONFIG)' -a -n '$(WORDS)' || { echo 'Pass CONFIG=<config.yaml> WORDS=<words.yaml> [SEED=n]'; exit 1; }
	swift run --quiet level-table '$(abspath $(CONFIG))' '$(abspath $(WORDS))' $(SEED)
