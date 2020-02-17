FROM drydock-prod.workiva.net/workiva/dart_build_image:1

RUN apt-get update && apt-get install -y \
        wget \
        # xvfb is used to run browser tests headless
        xvfb \
        && rm -rf /var/lib/apt/lists/*

# Install Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | tee /etc/apt/sources.list.d/google-chrome.list && \
    apt-get -qq update && apt-get install -y google-chrome-stable && \
    mv /usr/bin/google-chrome-stable /usr/bin/google-chrome && \
    sed -i --follow-symlinks -e 's/\"\$HERE\/chrome\"/\"\$HERE\/chrome\" --no-sandbox/g' /usr/bin/google-chrome && \
    google-chrome --version

RUN pub run dependency_validator
RUN xvfb-run -s '-screen 0 1024x768x24' pub run test --coverage=cov
RUN pub global activate coverage
RUN pub global run coverage:format_coverage -l -i cov -o lcov
ARG BUILD_ARTIFACTS_CODECOV=/build/lcov

FROM scratch
