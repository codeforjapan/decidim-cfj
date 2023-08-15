FROM node:16.13.0-bullseye-slim as node

FROM ruby:3.0.6-slim-bullseye

RUN  apt-get update && \
     apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        postgresql-client \
        libicu-dev \
        git \
        curl \
        wget && \
    apt-get clean && \
    apt-get autoremove

RUN wget https://github.com/ImageMagick/ImageMagick/archive/refs/tags/7.1.1-15.tar.gz && \
    tar xzf 7.1.1-15.tar.gz && \
    rm 7.1.1-15.tar.gz

RUN sh ./ImageMagick-7.1.1-15/configure --prefix=/usr/local --with-bzlib=yes --with-fontconfig=yes --with-freetype=yes --with-gslib=yes --with-gvc=yes --with-jpeg=yes --with-jp2=yes --with-png=yes --with-tiff=yes --with-xml=yes --with-gs-font-dir=yes && \
    make -j && make install && ldconfig /usr/local/lib/


ENV YARN_VERSION=v1.22.15

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
    BUNDLER_VERSION=2.2.33 \
    APP_HOME=/app \
    RAILS_ENV=${RAILS_ENV} \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    SECRET_KEY_BASE=placeholder \
    SLACK_API_TOKEN=xoxbdummy

WORKDIR $APP_HOME

COPY Gemfile Gemfile.lock ./

COPY decidim-comments /app/decidim-comments
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
