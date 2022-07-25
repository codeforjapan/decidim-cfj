FROM node:16.9.1-alpine as node

FROM ruby:2.7.4-alpine

RUN apk update \
    && apk add --no-cache --virtual build-dependencies \
        build-base \
        curl-dev \
        git \
    && apk add --no-cache \
        imagemagick \
        postgresql-dev \
        tzdata \
        zip \
    && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

ENV YARN_VERSION=v1.22.5

# node install
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /opt/yarn-${YARN_VERSION} /opt/yarn
RUN ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

ARG RAILS_ENV="production"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    BUNDLER_JOBS=4 \
    BUNDLER_VERSION=1.17.3 \
    APP_HOME=/app \
    RAILS_ENV=${RAILS_ENV} \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    SECRET_KEY_BASE=placeholder

WORKDIR $APP_HOME

COPY Gemfile Gemfile.lock ./

COPY decidim-comments /app/decidim-comments

# bundle install
RUN gem install bundler:${BUNDLER_VERSION} \
    && bundle config --global jobs ${BUNDLER_JOBS} \
    && if [ "${RAILS_ENV}" = "production" ];then \
            bundle install --without development test \
            && apk del --purge build-dependencies \
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
