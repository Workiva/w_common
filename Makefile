# Makefile for Dart projects.

.PHONY: analyze
analyze:
	dartanalyzer --fatal-warnings lib/ test/ example/

.PHONY: check-fast
check-fast: analyze
	pub run build_runner test -- -p chrome

.PHONY: check-full
check-full: check-fast format-check

.PHONY: format
format:
	pub run dart_style:format -w lib/ test/ example/

.PHONY: format-check
format-check:
	pub run dart_style:format -n --set-exit-if-changed lib/ test/ example/

.PHONY: init-dev
init-dev:
	pub get

.PHONY: init-ci
init-ci: init-dev
