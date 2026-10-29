SWIFT_SOURCES = Sources Tests Benchmarks Package.swift
BENCH_CONFIGURATION ?= release
BENCH_ARGS ?=
TEST_CONFIGURATION ?= debug
TEST_ARGS ?=
TEST_COST_OUTPUT ?= .build/test-costs.json
PROFILE_VERSION ?= 0.19
PROFILE_OPERATION ?= request
PROFILE_INPUT ?= 0
PROFILE_REPETITIONS ?= 20
PROFILE_TIME ?= 120s

.DEFAULT_GOAL := build

.PHONY: install-tools format lint comments test-build test build docs bench

install-tools:
	brew install swiftlint swift-format
	python3 -m pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git

format:
	swift-format format --in-place --recursive $(SWIFT_SOURCES)

.PHONY: format-preview
format-preview:
	@test -n '$(FORMAT_FILE)' || { echo 'FORMAT_FILE is required'; exit 1; }
	swift-format format '$(FORMAT_FILE)'

comments:
	commentcensor .

lint: comments
	swift-format lint --strict --recursive $(SWIFT_SOURCES)
	swiftlint --strict

test-build:
	swift build --build-tests

test:
	swift test --configuration $(TEST_CONFIGURATION) $(TEST_ARGS) $(if $(TEST),--filter '$(TEST)',)

.PHONY: test-list test-help test-costs
test-list:
	swift test list --skip-build --configuration $(TEST_CONFIGURATION)

test-help:
	swift test --help

test-costs:
	python3 Scripts/test_costs.py --configuration '$(TEST_CONFIGURATION)' --output '$(TEST_COST_OUTPUT)' $(if $(TEST_COST_FILTER),--filter '$(TEST_COST_FILTER)',)

build: lint test
	swift build

bench:
	swift run -c $(BENCH_CONFIGURATION) LetterGridBenchmarks $(BENCH_ARGS)

.PHONY: profile-build profile-run profile-launch profile-record profile-record-help profile-toc profile-export
profile-record-help:
	xcrun xctrace help record

profile-build:
	swift build -c release --product LetterGridBenchmarks

profile-run: profile-build
	.build/release/LetterGridBenchmarks --profile '$(PROFILE_VERSION)' '$(PROFILE_OPERATION)' \
		'$(PROFILE_INPUT)' '$(PROFILE_REPETITIONS)' --wait

profile-launch: profile-build
	@test -n '$(PROFILE_TRACE)' || { echo 'PROFILE_TRACE is required'; exit 1; }
	mkdir -p .build/profiles
	xcrun xctrace record --template 'Time Profiler' --no-prompt --time-limit '$(PROFILE_TIME)' \
		--output '$(PROFILE_TRACE)' --target-stdout - --launch -- \
		.build/release/LetterGridBenchmarks --profile '$(PROFILE_VERSION)' '$(PROFILE_OPERATION)' \
		'$(PROFILE_INPUT)' '$(PROFILE_REPETITIONS)'

profile-record:
	@test -n '$(PROFILE_PID)' -a -n '$(PROFILE_TRACE)' || { echo 'PROFILE_PID and PROFILE_TRACE are required'; exit 1; }
	mkdir -p .build/profiles
	xcrun xctrace record --template 'Time Profiler' --no-prompt --time-limit '$(PROFILE_TIME)' \
		--output '$(PROFILE_TRACE)' --attach '$(PROFILE_PID)'

profile-toc:
	@test -n '$(PROFILE_TRACE)' || { echo 'PROFILE_TRACE is required'; exit 1; }
	xcrun xctrace export --input '$(PROFILE_TRACE)' --toc

profile-export:
	@test -n '$(PROFILE_TRACE)' -a -n '$(PROFILE_XPATH)' || { echo 'PROFILE_TRACE and PROFILE_XPATH are required'; exit 1; }
	xcrun xctrace export --input '$(PROFILE_TRACE)' --xpath '$(PROFILE_XPATH)' $(if $(PROFILE_XML),--output '$(PROFILE_XML)',)

docs:
	mkdir -p .build/docc
	swift package --allow-writing-to-directory .build/docc generate-documentation \
		--target LetterGrid --output-path .build/docc --warnings-as-errors \
		--transform-for-static-hosting --hosting-base-path lettergrid-swift
	swift package --allow-writing-to-directory .build/docc/ui generate-documentation \
		--target LetterGridUI --output-path .build/docc/ui --warnings-as-errors \
		--transform-for-static-hosting --hosting-base-path lettergrid-swift/ui
