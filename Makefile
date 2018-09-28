# Makefile for Dart projects.

.PHONY: check-fast
check-fast:
	pub run build_runner test -- -p chrome

init-dev:
	pub get
