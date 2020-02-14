FROM drydock-prod.workiva.net/workiva/dart_build_image:1

RUN pub run dependency_validator
RUN pub run build_runner test --delete-conflicting-outputs -- --coverage=cov
RUN pub global activate coverage
RUN pub global run coverage:format_coverage -l -i cov -o lcov
ARG BUILD_ARTIFACTS_CODECOV=/build/lcov

FROM scratch
