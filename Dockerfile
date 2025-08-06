FROM node:20.18.3-bookworm-slim AS node

FROM ruby:3.3.4-slim-bookworm

# for build-dep
RUN  apt-get update && \
     apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        postgresql-client \
        libicu-dev \
        libwebp-dev \
        libopenjp2-7-dev \
        librsvg2-dev \
        libde265-dev \
        git \
        curl \
        p7zip \
        wkhtmltopdf \
        chromium-driver \
        wget && \
    apt-get clean && \
    apt-get autoremove

RUN echo "deb http://deb.debian.org/debian trixie main" \
      > /etc/apt/sources.list.d/trixie.list \
 && printf '%s\n' \
      'Package: *' \
      'Pin: release a=trixie' \
      'Pin-Priority: 100' \
      '' \
      'Package: imagemagick*' \
      'Pin: release a=trixie' \
      'Pin-Priority: 990' \
      > /etc/apt/preferences.d/99-trixie \
 && apt-get update \
 && apt-get install -y -t trixie imagemagick \
 && rm -rf /var/lib/apt/lists/*

# node install
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /opt/yarn-* /opt/yarn
RUN ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

ARG RAILS_ENV="production"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    BUNDLER_JOBS=4 \
    BUNDLER_VERSION=2.5.15 \
    APP_HOME=/app \
    RAILS_ENV=${RAILS_ENV} \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    SECRET_KEY_BASE=placeholder \
    SLACK_API_TOKEN=xoxbdummy

WORKDIR $APP_HOME

COPY Gemfile Gemfile.lock ./

COPY omniauth-line_login /app/omniauth-line_login
COPY decidim-user_extension /app/decidim-user_extension

# bundle install
RUN gem install bundler:${BUNDLER_VERSION} \
    && bundle config --global jobs ${BUNDLER_JOBS} \
    && if [ "${RAILS_ENV}" = "production" ];then \
            bundle install --without development test \
        ;else \
            bundle install \
        ;fi

COPY . $APP_HOME

RUN cp ./entrypoint /usr/bin/entrypoint \
    && chmod +x /usr/bin/entrypoint \
    && chmod -R +x ./bin/

RUN yarn install \
    && ./bin/rails assets:precompile \
    && yarn cache clean

ENTRYPOINT ["entrypoint"]

EXPOSE 3000

CMD ["./bin/rails", "s", "-b", "0.0.0.0"]
