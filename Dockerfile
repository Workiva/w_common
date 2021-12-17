FROM google/dart
WORKDIR /build/
ADD pubspec.yaml /build/
RUN pub get
ADD . /build/
RUN pub run dependency_validator
RUN dartanalyzer .
RUN dartfmt --dry-run --set-exit-if-changed .
RUN pub run test
FROM scratch
