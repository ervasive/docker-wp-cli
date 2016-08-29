#! /bin/bash
set -e

# Check if all required variables defined.
# -----------------------------------------------------------------------------
required_vars=(\
    DWC_WP_DB_NAME \
    DWC_WP_DB_USER \
    DWC_WP_DB_PASS \
    DWC_WP_ROOT \
    DWC_WP_HOME \
    DWC_WP_ADMIN_USER \
    DWC_WP_ADMIN_PASS \
    DWC_WP_ADMIN_EMAIL \
)

for var in "${required_vars[@]}" ; do
    if [[ "" == ${!var} ]] ; then
        echo "Error: Required variable $var is not defined."
        exit 1
    fi
done


# Setup optional variables with default values
# -----------------------------------------------------------------------------
DWC_WP_DB_TABLE_PREFIX=${DWC_WP_DB_TABLE_PREFIX:=wp_}
DWC_WP_LANG=${DWC_WP_LANG:="en_US"}
DWC_WP_VERSION=${DWC_WP_VERSION:="latest"}
DWC_WP_DEBUG=${DWC_WP_DEBUG:=false}


# Alter PHP configuration directives for development mode.
# -----------------------------------------------------------------------------
if [[ $DWC_WP_DEBUG == true ]] ; then
    echo "Notice: Altering PHP configuration for development mode."
    sed -i "/opcache.revalidate_freq=.*/c\opcache.revalidate_freq=0" /usr/local/etc/php/conf.d/opcache-recommended.ini
fi


# Prepare WordPress root directory.
# -----------------------------------------------------------------------------
if [[ ! -e $DWC_WP_ROOT ]] ; then
    echo "Notice: Creating WordPress root directory..."
    mkdir -p $DWC_WP_ROOT
fi

cd $DWC_WP_ROOT


# Normalize access rights for wp-content directory
# -----------------------------------------------------------------------------
mkdir -p "$DWC_WP_ROOT/wp-content"
mkdir -p "$DWC_WP_ROOT/wp-content/themes"
mkdir -p "$DWC_WP_ROOT/wp-content/plugins"

chown www-data:www-data "$DWC_WP_ROOT"
chown www-data:www-data "$DWC_WP_ROOT/wp-content"
chown www-data:www-data "$DWC_WP_ROOT/wp-content/themes"
chown www-data:www-data "$DWC_WP_ROOT/wp-content/plugins"


# Start installation process
# -----------------------------------------------------------------------------
if ! $(wp core is-installed) ; then

    # Download & extract WP
    # ---------------------------
    wp_entries=(wp-admin wp-content wp-includes index.php)
    wp_valid=true

    for wp_entry in "${wp_entries[@]}" ; do
        if [[ ! -e "$DWC_WP_ROOT/$wp_entry" ]] ; then
            wp_valid=false
        fi
    done

    if [[ $wp_valid == true ]] ; then
        echo "Notice: WordPress installation seems fine, no need to re-download."
    else
        wp core download --locale=$DWC_WP_LANG --path=$DWC_WP_ROOT --version=$DWC_WP_VERSION
    fi

    # (Re)Generate wp-config.php file
    # ---------------------------
    rm -f "$DWC_WP_ROOT/wp-config.php"

    extra_php=()
    extra_php+="define( 'WP_HOME', '$DWC_WP_HOME' );"
    extra_php+="define( 'WP_SITEURL', '$DWC_WP_HOME' );"

    if [[ $DWC_WP_DEBUG == true ]] ; then
        extra_php+="define( 'WP_DEBUG', true );"
        extra_php+="define( 'SAVEQUERIES', true );"
    fi

    wp core config \
        --dbhost=database \
        --dbname=$DWC_WP_DB_NAME \
        --dbuser=$DWC_WP_DB_USER \
        --dbpass=$DWC_WP_DB_PASS \
        --dbprefix=$DWC_WP_DB_TABLE_PREFIX \
        --locale=$DWC_WP_LANG \
        --skip-check \
        --extra-php <<PHP
$extra_php
PHP

    # Next step requires working database connection, so let's wait for it if necessary.
    # ---------------------------
    dbhost_counter=0

    until [[ $(mysqladmin -h database -u$DWC_WP_DB_USER -p$DWC_WP_DB_PASS status | awk '{print $1}') == "Uptime:" ]] &>/dev/null ; do
        echo "Notice: Database server is not ready yet - waiting…"
        sleep 1
        let dbhost_counter=dbhost_counter+1

        if [[ $dbhost_counter -gt 30 ]] ; then
            echo "Error: Could not connect to database server. Exiting."
            exit 1
        fi
    done

    echo "Notice: Database server is ready - continuing…"

    # Install WordPress by importing DB dump or run installation process.
    # ---------------------------
    if ! $(wp core is-installed) ; then
        if [[ -n $DWC_WP_DB_IMPORT_FILENAME ]] ; then
            if [[ -f "/database/$DWC_WP_DB_IMPORT_FILENAME" ]] ; then
                wp db import "/database/$DWC_WP_DB_IMPORT_FILENAME"
            else
                echo "Error: \$DWC_WP_DB_IMPORT_FILENAME variable was set but file is not present"
                exit 1
            fi
        else
            wp core install \
                --url=$DWC_WP_HOME \
                --title="WordPress" \
                --admin_user=$DWC_WP_ADMIN_USER \
                --admin_password=$DWC_WP_ADMIN_PASS \
                --admin_email=$DWC_WP_ADMIN_EMAIL \
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

    user_plugins=(${DWC_WP_PLUGINS})
    installed_plugins=($(wp plugin list --field=name))

    if [[ $DWC_WP_DEBUG == true ]] ; then
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

    if [[ $DWC_WP_DEBUG == true ]] ; then
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
    if [[ -n $DWC_WP_THEME ]] ; then
        wp theme install $DWC_WP_THEME --activate
    fi
fi


# Load user entry point additions
# -----------------------------------------------------------------------------
if [[ -e /user-entrypoint.sh ]] ; then
    if [[ ! -x /user-entrypoint.sh ]] ; then
        chmod +x /user-entrypoint.sh
    fi

    source /user-entrypoint.sh
fi


# Unsetting sensitive variables
# -----------------------------------------------------------------------------
unset DWC_WP_ADMIN_USER
unset DWC_WP_ADMIN_PASS
unset DWC_WP_ADMIN_EMAIL


# Start container's main process
# -----------------------------------------------------------------------------
exec php-fpm
