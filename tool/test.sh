#!/bin/bash
# Fast fail the script on failures.
set -e
DART_VERSION=$(dart --version 2>&1)
DART_2_PREFIX="Dart VM version: 2"
 if [[ $DART_VERSION = $DART_2_PREFIX* ]]; then
    echo -e 'pub run build_runner test -- -p chrome -p vm --reporter=expanded'
    pub run build_runner test -- -p chrome -p vm --reporter=expanded
else
    echo -e 'pub run dart_dev test --pub-serve --web-compiler=dartdevc -p chrome -p vm'
    pub run dart_dev test --pub-serve --web-compiler=dartdevc -p chrome -p vm
fi 