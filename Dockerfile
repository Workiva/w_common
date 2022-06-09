FROM dart:2.13.4
WORKDIR /w_common_build/
ADD w_common/pubspec.yaml /w_common_build/
RUN dart pub get
WORKDIR /w_common_tools_build/
ADD w_common_tools/pubspec.yaml /w_common_tools_build/
RUN dart pub get
FROM scratch
