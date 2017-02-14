FROM php:7.0-fpm-alpine

# Waiting in anticipation for build-time arguments
# https://github.com/docker/docker/issues/14634
ENV MEDIAWIKI_VERSION 1.28
ENV MEDIAWIKI_VERSION_FULL 1.28.0

RUN set -xe; \
    apk add --no-cache --virtual .persistent-deps \
        imagemagick \
		icu-libs \
		libldap \
		nginx

# Add needed php modules
RUN set -xe; \
    apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
        libpng-dev \
        icu-dev \
		openldap-dev \
	&& docker-php-ext-configure ldap \
    && docker-php-ext-install ldap opcache gd intl \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
	&& apk del .build-deps

# Install composer
RUN set -xe; \
	apk add --no-cache --virtual .fetch-deps \
		gnupg \
		openssl \
	&& EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig) \
	&& php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
	&& ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', 'composer-setup.php');") \
	&& if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then \
	    >&2 echo 'ERROR: Invalid installer signature'; \
	    rm composer-setup.php; \
	    exit 1; \
	fi \
	&& php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm composer-setup.php \
	&& apk del .fetch-deps

# Install Application
RUN set -xe; \
	apk add --no-cache --virtual .fetch-deps \
		gnupg \
		openssl \
	# https://www.mediawiki.org/keys/keys.txt \
	&& gpg --keyserver pool.sks-keyservers.net --recv-keys \
	    441276E9CCD15F44F6D97D18C119E1A64D70938E \
	    41B2ABE817ADD3E52BDA946F72BC1C5D23107F8A \
	    162432D9E81C1C618B301EECEE1F663462D84F01 \
	    1D98867E82982C8FE0ABC25F9B69B3109D3BB7B0 \
	    3CEF8262806D3F0B6BA1DBDD7956EE477F901A30 \
	    280DB7845A1DCAC92BB5A00A946B02565DC00AA7 \
    && export MEDIAWIKI_DOWNLOAD_URL="https://releases.wikimedia.org/mediawiki/$MEDIAWIKI_VERSION/mediawiki-$MEDIAWIKI_VERSION_FULL.tar.gz" \
    && curl -fSL "$MEDIAWIKI_DOWNLOAD_URL" -o mediawiki.tar.gz \
    && curl -fSL "${MEDIAWIKI_DOWNLOAD_URL}.sig" -o mediawiki.tar.gz.sig \
    && gpg --verify mediawiki.tar.gz.sig \
    && tar -xf mediawiki.tar.gz -C /var/www/html --strip-components=1 \
	&& rm *.tar.gz *.sig \
	&& apk del .fetch-deps
	
COPY php.ini /usr/local/etc/php/conf.d/mediawiki.ini

COPY docker-entrypoint.sh /entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apachectl", "-e", "info", "-D", "FOREGROUND"]
