#! /bin/bash
set -e

# -----------------------------------------------------------------------------
# This is a wrapper so that wp-cli can run as the www-data user so that
# permissions remain correct
# -----------------------------------------------------------------------------
WP_ROOT=${WP_ROOT:=/usr/share/nginx/html}

sudo -u www-data /bin/wp-cli.phar --path=$WP_ROOT --color $*
