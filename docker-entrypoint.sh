#! /bin/bash
set -e

# Check if all required variables defined.
# -----------------------------------------------------------------------------
required_vars=(\
    MYSQL_HOSTNAME \
    MYSQL_DATABASE \
    MYSQL_USER \
    MYSQL_PASSWORD \
    WP_HOME \
    WP_ADMIN_USER \
    WP_ADMIN_PASS \
    WP_ADMIN_EMAIL \
)

for var in "${required_vars[@]}" ; do
    if [[ "" == ${!var} ]] ; then
        echo "Error: Required variable $var is not defined."
        exit 1
    fi
done


# Setup optional variables with default values
# -----------------------------------------------------------------------------
WP_ROOT=${WP_ROOT:=/usr/share/nginx/html}
WP_LANG=${WP_LANG:="en_US"}
WP_VERSION=${WP_VERSION:="latest"}
WP_DEBUG=${WP_DEBUG:=false}


# Alter PHP configuration directives for development mode.
# -----------------------------------------------------------------------------
if [[ $WP_DEBUG == true ]] ; then
    echo "Notice: Altering PHP configuration for development mode."
    sed -i "/opcache.revalidate_freq=.*/c\opcache.revalidate_freq=0" /usr/local/etc/php/conf.d/opcache-recommended.ini
fi


# Prepare WordPress root directory.
# -----------------------------------------------------------------------------
if [[ ! -e $WP_ROOT ]] ; then
    echo "Notice: Creating WordPress root directory..."
    mkdir -p $WP_ROOT
fi

cd $WP_ROOT


# Normalize access rights for wp-content directory
# -----------------------------------------------------------------------------
mkdir -p "$WP_ROOT/wp-content"
mkdir -p "$WP_ROOT/wp-content/themes"
mkdir -p "$WP_ROOT/wp-content/plugins"

chown www-data:www-data "$WP_ROOT"
chown www-data:www-data "$WP_ROOT/wp-content"
chown www-data:www-data "$WP_ROOT/wp-content/themes"
chown www-data:www-data "$WP_ROOT/wp-content/plugins"


# Start installation process
# -----------------------------------------------------------------------------
if ! $(wp core is-installed) ; then

    # Download & extract WP
    # ---------------------------
    wp_entries=(wp-admin wp-content wp-includes index.php)
    wp_valid=true

    for wp_entry in "${wp_entries[@]}" ; do
        if [[ ! -e "$WP_ROOT/$wp_entry" ]] ; then
            wp_valid=false
        fi
    done

    if [[ $wp_valid == true ]] ; then
        echo "Notice: WordPress installation seems fine, no need to re-download."
    else
        wp core download --locale=$WP_LANG --path=$WP_ROOT --version=$WP_VERSION
    fi

    # (Re)Generate wp-config.php file
    # ---------------------------
    rm -f "$WP_ROOT/wp-config.php"

    extra_php=()
    extra_php+="define( 'WP_HOME', '$WP_HOME' );"
    extra_php+="define( 'WP_SITEURL', '$WP_HOME' );"

    if [[ $WP_DEBUG == true ]] ; then
        extra_php+="define( 'WP_DEBUG', true );"
        extra_php+="define( 'SAVEQUERIES', true );"
    fi

    wp core config \
        --dbhost=$MYSQL_HOSTNAME \
        --dbname=$MYSQL_DATABASE \
        --dbuser=$MYSQL_USER \
        --dbpass=$MYSQL_PASSWORD \
        --dbprefix=$WP_TABLE_PREFIX \
        --locale=$WP_LANG \
        --skip-check \
        --extra-php <<PHP
$extra_php
PHP

    # Next step requires working database connection, so let's wait for it if necessary.
    # ---------------------------
    dbhost_counter=0

    until [[ $(mysqladmin -h db -u$MYSQL_USER -p$MYSQL_PASSWORD status | awk '{print $1}') == "Uptime:" ]] &>/dev/null ; do
        echo "Notice: Database server is not ready yet - waiting…"
        sleep 1
        let dbhost_counter=dbhost_counter+1

        if [[ $dbhost_counter -gt 20 ]] ; then
            echo "Error: Could not connect to database server. Exiting."
            exit 1
        fi
    done

    echo "Notice: Database server is ready - continuing…"

    # Install WordPress by importing DB dump or run installation process.
    # ---------------------------
    if ! $(wp core is-installed) ; then
        if [[ -n $WP_DB_DUMP ]] ; then
            if [[ -f "/database/$WP_DB_DUMP" ]] ; then
                wp db import "/database/$WP_DB_DUMP"
            else
                echo "Error: \$WP_DB_DUMP variable was set but file is not present"
                exit 1
            fi
        else
            wp core install \
                --url=$WP_HOME \
                --title="WordPress" \
                --admin_user=$WP_ADMIN_USER \
                --admin_password=$WP_ADMIN_PASS \
                --admin_email=$WP_ADMIN_EMAIL \
                --skip-email
        fi
    else
        echo "Notice: WordPress database tables are already present. Skiping database installation."
    fi

    # Install required plugins
    # ---------------------------
    development_plugins=(\
        debug-bar \
        debug-bar-console \
        debug-bar-cron \
        debug-bar-extender \
        rewrite-rules-inspector \
        log-deprecated-notices \
        log-viewer \
        monster-widget \
        user-switching \
        rtl-tester \
        regenerate-thumbnails \
        simply-show-ids \
        theme-check \
    )

    user_plugins=(${WP_PLUGINS})
    installed_plugins=($(wp plugin list --field=name))

    if [[ $WP_DEBUG == true ]] ; then
        for plugin in "${development_plugins[@]}" ; do
            if ! [[ ${installed_plugins[*]} =~ $plugin ]]; then
                wp plugin install $plugin
            fi
        done
    fi

    for plugin in "${user_plugins[@]}" ; do
        if ! [[ ${installed_plugins[*]} =~ $plugin ]]; then
            wp plugin install $plugin
        fi
    done

    # Activate installed plugins
    # ---------------------------
    activated_plugins=($(wp plugin list --field=name --status=active))

    if [[ $WP_DEBUG == true ]] ; then
        for plugin in "${development_plugins[@]}" ; do
            if ! [[ ${activated_plugins[*]} =~ $plugin ]]; then
                wp plugin activate $plugin
            fi
        done
    fi

    for plugin in "${user_plugins[@]}" ; do
        if ! [[ ${activated_plugins[*]} =~ $plugin ]]; then
            wp plugin activate $plugin
        fi
    done

    # Install required theme
    # ---------------------------
    if [[ -n $WP_THEME ]] ; then
        wp theme install $WP_THEME --activate
    fi
fi


# Start container's main process
# -----------------------------------------------------------------------------
exec php-fpm
