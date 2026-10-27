SWIFT_SOURCES = Sources Tests Benchmarks Package.swift
BENCH_CONFIGURATION ?= release

.DEFAULT_GOAL := build

.PHONY: install-tools format lint comments test-build test build docs bench

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

bench:
	swift run -c $(BENCH_CONFIGURATION) LetterGridBenchmarks

docs:
	mkdir -p .build/docc
	swift package --allow-writing-to-directory .build/docc generate-documentation \
		--target LetterGrid --output-path .build/docc --warnings-as-errors \
		--transform-for-static-hosting --hosting-base-path lettergrid-swift
	swift package --allow-writing-to-directory .build/docc/ui generate-documentation \
		--target LetterGridUI --output-path .build/docc/ui --warnings-as-errors \
		--transform-for-static-hosting --hosting-base-path lettergrid-swift/ui
