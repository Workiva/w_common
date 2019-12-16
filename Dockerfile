FROM drydock-prod.workiva.net/workiva/dart2_base_image:0.0.0-dart2.7.0
WORKDIR /build/
ADD pubspec.yaml /build/
RUN pub get
ADD . /build/
RUN pub run dependency_validator
FROM scratch
