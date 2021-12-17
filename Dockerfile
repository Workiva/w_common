FROM google/dart
WORKDIR /build/
ADD pubspec.yaml /build/
RUN pub get
ADD . /build/
RUN pub run dependency_validator
RUN pub run test
FROM scratch
