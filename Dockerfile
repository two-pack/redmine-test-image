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
        mariadb-server \
        libmariadb-dev
RUN apt-get -y install --no-install-recommends \
        sudo \
        curl \
        ca-certificates \
        gnupg \
 && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
 && apt-get -y update \
 && apt-get -y install postgresql-11 postgresql-server-dev-11 \
 && sh -c "sed s/#listen_addresses\ =\ \'localhost\'/listen_addresses\ =\ \'*\'/ -i /etc/postgresql/11/main/postgresql.conf"
RUN rm -rf /var/lib/apt/lists/*

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
ENV REDMINE_DB_SQLITE3=${PATH_TO_REDMINE}/config/database.yml.sqlite3
ENV REDMINE_DB_POSTGRESQL=${PATH_TO_REDMINE}/config/database.yml.postgresql
ENV REDMINE_DB_MYSQL=${PATH_TO_REDMINE}/config/database.yml.mysql

WORKDIR ${PATH_TO_REDMINE}
RUN git clone -b ${REDMINE_VERSION} --depth 1 ${REDMINE_GIT_REPO} ${PATH_TO_REDMINE} \
 && mkdir -p vendor/bundle

# for sqlite3
RUN echo "development:" >> ${REDMINE_DB_SQLITE3} \
 && echo "  adapter: sqlite3" >> ${REDMINE_DB_SQLITE3} \
 && echo "  database: db/redmine_dev.sqlite3" >> ${REDMINE_DB_SQLITE3} \
 && echo "test:" >> ${REDMINE_DB_SQLITE3} \
 && echo "  adapter: sqlite3" >> ${REDMINE_DB_SQLITE3} \
 && echo "  database: db/redmine_test.sqlite3" >> ${REDMINE_DB_SQLITE3}
# for postgresql
RUN echo "development:" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  adapter: postgresql" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  database: redmine" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  host: localhost" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  username: redmine" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  password: ""redmine""" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "test:" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  adapter: postgresql" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  database: redmine_test" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  host: localhost" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  username: redmine" >> ${REDMINE_DB_POSTGRESQL} \
 && echo "  password: ""redmine""" >> ${REDMINE_DB_POSTGRESQL}
# for mysql
RUN echo "development:" >> ${REDMINE_DB_MYSQL} \
 && echo "  adapter: mysql2" >> ${REDMINE_DB_MYSQL} \
 && echo "  database: redmine" >> ${REDMINE_DB_MYSQL} \
 && echo "  host: localhost" >> ${REDMINE_DB_MYSQL} \
 && echo "  username: root" >> ${REDMINE_DB_MYSQL} \
 && echo "  password: """"" >> ${REDMINE_DB_MYSQL} \
 && echo "  encoding: utf8mb4" >> ${REDMINE_DB_MYSQL} \
 && echo "test:" >> ${REDMINE_DB_MYSQL} \
 && echo "  adapter: mysql2" >> ${REDMINE_DB_MYSQL} \
 && echo "  database: redmine_test" >> ${REDMINE_DB_MYSQL} \
 && echo "  host: localhost" >> ${REDMINE_DB_MYSQL} \
 && echo "  username: root" >> ${REDMINE_DB_MYSQL} \
 && echo "  password: """"" >> ${REDMINE_DB_MYSQL} \
 && echo "  encoding: utf8mb4" >> ${REDMINE_DB_MYSQL}

# Prepare database for sqlites
RUN cp ${REDMINE_DB_SQLITE3} ${REDMINE_DB} \
 && bundle install --path vendor/bundle \
 && bundle exec rake db:migrate \
 && bundle exec rake redmine:load_default_data REDMINE_LANG=en \
 && bundle exec rake generate_secret_token

# Prepare database for postgresql
RUN cp ${REDMINE_DB_POSTGRESQL} ${REDMINE_DB} \
 && bundle install --path vendor/bundle \
 && service postgresql start \
 && sudo -u postgres psql -q -U postgres -c "CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD 'redmine' NOINHERIT VALID UNTIL 'infinity';" \
 && sudo -u postgres psql -q -U postgres -c "ALTER ROLE redmine WITH CREATEDB;" \
 && sudo -u postgres psql -q -U postgres -c "CREATE DATABASE redmine WITH ENCODING='UTF8' OWNER=redmine;" \
 && sudo -u postgres psql -q -U postgres -c "CREATE DATABASE redmine_test WITH ENCODING='UTF8' OWNER=redmine;" \
 && bundle exec rake db:migrate \
 && bundle exec rake redmine:load_default_data REDMINE_LANG=en \
 && bundle exec rake generate_secret_token

# Prepare database for mysql
RUN cp ${REDMINE_DB_MYSQL} ${REDMINE_DB} \
 && bundle install --path vendor/bundle \
 && service mysql start \
 && mysql -u root -e"CREATE DATABASE redmine CHARACTER SET utf8mb4;" \
 && mysql -u root -e"CREATE DATABASE redmine_test CHARACTER SET utf8mb4;" \
 && mysql -u root -e"CREATE USER 'redmine'@'localhost' IDENTIFIED BY 'redmine';" \
 && mysql -u root -e"GRANT ALL PRIVILEGES ON redmine.* TO 'redmine'@'localhost';" \
 && mysql -u root -e"GRANT ALL PRIVILEGES ON redmine_test.* TO 'redmine'@'localhost';" \
 && bundle exec rake db:migrate \
 && bundle exec rake redmine:load_default_data REDMINE_LANG=en \
 && bundle exec rake generate_secret_token
