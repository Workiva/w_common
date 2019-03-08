#!/bin/sh
set -e

dartfmt -w --set-exit-if-changed example lib test tool
