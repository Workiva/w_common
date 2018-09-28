# Makefile for Dart projects.

.PHONY: check-fast
check-fast:
	pub run build_runner test -- -p chrome

.PHONY: format
format:
	dartfmt -w lib/ test/ example/

.PHONY: init-dev
init-dev:
	pub get
