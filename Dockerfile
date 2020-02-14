FROM drydock-prod.workiva.net/workiva/dart2_base_image:1
WORKDIR /build/
ADD pubspec.yaml /build/
RUN pub get
ADD . /build/
RUN pub run dependency_validator

RUN pub run build_runner test --delete-conflicting-outputs --coverage=cov
RUN pub global activate coverage
RUN pub global run coverage:format_coverage -l -i cov -o lcov
ARG BUILD_ARTIFACTS_CODECOV=lcov

FROM scratch
