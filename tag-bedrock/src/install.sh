#!/bin/bash
# Demyx
# https://demyx.sh
set -euo pipefail

# Support for old variables
[[ -n "${WORDPRESS_DB_HOST:-}" ]] && DEMYX_DB_HOST="$WORDPRESS_DB_HOST"
[[ -n "${WORDPRESS_DB_NAME:-}" ]] && DEMYX_DB_NAME="$WORDPRESS_DB_NAME"
[[ -n "${WORDPRESS_DB_PASSWORD:-}" ]] && DEMYX_DB_PASSWORD="$WORDPRESS_DB_PASSWORD"
[[ -n "${WORDPRESS_DB_USER:-}" ]] && DEMYX_DB_USER="$WORDPRESS_DB_USER"
[[ -n "${WORDPRESS_DOMAIN:-}" ]] && DEMYX_DOMAIN="$WORDPRESS_DOMAIN"
[[ -n "${WORDPRESS_SSL:-}" ]] && DEMYX_SSL="$WORDPRESS_SSL"

# Define variables
DEMYX_ENV="$DEMYX"/.env
DEMYX_PROTO="http://$DEMYX_DOMAIN"
[[ "$DEMYX_SSL" = true ]] && DEMYX_PROTO="https://$DEMYX_DOMAIN"

if [[ ! -d "$DEMYX"/web ]]; then
    /bin/echo "[demyx] Bedrock is missing, copying files now ..."
    /bin/tar -xzf "$DEMYX_CONFIG"/bedrock.tgz -C "$DEMYX"
fi

if [[ ! -f "$DEMYX_ENV" ]]; then
    /bin/echo "[demyx] Generating Bedrock .env file ..."
    /bin/cp "$DEMYX_CONFIG"/bedrock/.env "$DEMYX"
fi

if [[ -n "$(/bin/grep example.com "$DEMYX_ENV" || true)" ]]; then
    /bin/echo "[demyx] Configuring Bedrock .env file ..."

    /bin/sed -i "s|WP_HOME=.*|WP_HOME=$DEMYX_PROTO|g" "$DEMYX_ENV"
    /bin/sed -i "s|database_name|$DEMYX_DB_NAME|g" "$DEMYX_ENV"
    /bin/sed -i "s|database_user|$DEMYX_DB_USER|g" "$DEMYX_ENV"
    /bin/sed -i "s|database_password|$DEMYX_DB_PASSWORD|g" "$DEMYX_ENV"
    /bin/sed -i "s|# DB_HOST='localhost'|DB_HOST='$DEMYX_DB_HOST'|g" "$DEMYX_ENV"
    /bin/sed -i "s|WP_ENV=.*|WP_ENV=production|g" "$DEMYX_ENV"
    SALT="$(/usr/bin/wget -qO- https://api.wordpress.org/secret-key/1.1/salt/ | /bin/sed "s|define('||g" | /bin/sed "s|',|=|g" | /bin/sed "s| ||g" | /bin/sed "s|);||g")"
    /usr/bin/printf '%s\n' "g/generateme/d" a "$SALT" . w | /bin/ed -s "$DEMYX_ENV"

    /usr/local/bin/wp core install \
        --url="${DEMYX_DOMAIN:-}" \
        --title="${DEMYX_DOMAIN:-}" \
        --admin_user="${DEMYX_ADMIN_USER:-}" \
        --admin_password="${DEMYX_ADMIN_PASSWORD:-}" \
        --admin_email="${DEMYX_ADMIN_EMAIL:-}" \
        --skip-email
    /usr/local/bin/wp rewrite structure '/%category%/%postname%/'
    /usr/local/bin/wp config shuffle-salts
fi
