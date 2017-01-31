FROM php:7-apache

# Waiting in antiticipation for build-time arguments
# https://github.com/docker/docker/issues/14634
ENV MEDIAWIKI_VERSION wmf/1.29.0-wmf.9
# the above is volatile
# to get the latest see https://gerrit.wikimedia.org/r/#/admin/projects/mediawiki/core,branches

RUN set -x; \
    export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        imagemagick \
        libpng-dev \
        libicu52 libicu-dev \
        netcat \
        git \
        locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure locales && locale-gen --purge en_US en_US.UTF-8 && update-locale LANG=en_US.UTF-8 \
    && export LC_ALL=en_US.UTF-8 \
    && pecl install apcu \
    && docker-php-ext-install mysqli opcache gd intl\
    && docker-php-ext-enable apcu \
    \
    && a2enmod rewrite \
    && a2enmod proxy \
    && a2enmod proxy_http \
    \
    && mkdir -p /var/www/html \
    && git clone \
        --depth 1 \
        -b $MEDIAWIKI_VERSION \
        https://gerrit.wikimedia.org/r/p/mediawiki/core.git \
        /var/www/html \
    && cd /var/www/html \
    && git submodule update --init skins \
    && git submodule update --init vendor \
    && cd extensions \
    # VisualEditor
    # TODO: make submodules shallow clones?
    && git submodule update --init VisualEditor \
    && cd VisualEditor \
    && git checkout $MEDIAWIKI_VERSION \
    && git submodule update --init \
    && export DEBIAN_FRONTEND="" \
    \
    && apt-get remove -yq --purge libpng-dev libicu-dev g++ \
    && apt-get clean \
    && du -sh /var/www/html \
    && apt-get -qq clean \
	&& rm -rf /tmp/* /var/tmp/* /var/cache/apt/* /var/lib/apt/lists/* \
	&& apt-get -yq autoremove --purge

COPY php.ini /usr/local/etc/php/conf.d/mediawiki.ini

COPY apache/mediawiki.conf /etc/apache2/
RUN echo "Include /etc/apache2/mediawiki.conf" >> /etc/apache2/apache2.conf

COPY docker-entrypoint.sh /entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apachectl", "-e", "info", "-D", "FOREGROUND"]
