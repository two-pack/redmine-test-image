ARG RUBY_VERSION
FROM ruby:${RUBY_VERSION}-slim
ARG REDMINE_VERSION

RUN apt-get -y update \
 && apt-get -y install --no-install-recommends \
        build-essential libsqlite3-dev git wget unzip \
        lsb-release \
        fonts-liberation \
        libappindicator3-1 \
        libasound2 \
        libatk-bridge2.0-0 \
        libatspi2.0-0 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libx11-xcb1 \
        libxss1 \
        libxtst6 \
        xdg-utils \
        ruby-rmagick \
        libmagick++-dev \
        gnupg2 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN mkdir instchrome \
 && cd instchrome \
 && export CHROME_VER=`wget -q https://chromedriver.storage.googleapis.com/LATEST_RELEASE -O -` \
 && export CHROME_DL_URL=https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
 && export CHROMEDRV_DL_URL=https://chromedriver.storage.googleapis.com/${CHROME_VER}/chromedriver_linux64.zip \
 && wget -q -c -nc --retry-connrefused --tries=0 ${CHROME_DL_URL} \
 && dpkg -i google-chrome-stable_current_amd64.deb \
 && wget -q -c -nc --retry-connrefused --tries=0 https://dl.google.com/linux/linux_signing_key.pub \
 && apt-key add linux_signing_key.pub \
 && wget -q -c -nc --retry-connrefused --tries=0 ${CHROMEDRV_DL_URL} \
 && unzip chromedriver_linux64.zip \
 && mv chromedriver /usr/bin/ \
 && chmod +x /usr/bin/chromedriver \
 && cd .. \
 && rm -rf instchrome

ENV REDMINE_GIT_REPO=https://github.com/redmine/redmine.git
ENV PATH_TO_REDMINE=/var/lib/redmine
ENV REDMINE_DB=${PATH_TO_REDMINE}/config/database.yml
WORKDIR ${PATH_TO_REDMINE}
RUN git clone -b ${REDMINE_VERSION} --depth 1 ${REDMINE_GIT_REPO} ${PATH_TO_REDMINE}
RUN echo "development:" >> ${REDMINE_DB} && \
    echo "  adapter: sqlite3" >> ${REDMINE_DB} && \
    echo "  database: db/redmine_dev.sqlite3" >> ${REDMINE_DB} && \
    echo "test:" >> ${REDMINE_DB} && \
    echo "  adapter: sqlite3" >> ${REDMINE_DB} && \
    echo "  database: db/redmine_test.sqlite3" >> ${REDMINE_DB}
RUN mkdir -p vendor/bundle && \
    bundle install --path vendor/bundle && \
    bundle exec rake db:migrate && \
    bundle exec rake redmine:load_default_data REDMINE_LANG=en && \
    bundle exec rake generate_secret_token
