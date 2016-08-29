# WordPress with WP-CLI [Docker image]

Install and configure WordPress dynamically, based on number of environment variables.

This image is meant to be used as a part of specific Docker Compose project and it doesn't include any database nor web servers.
For more information about how to run this image go to the [project repo](https://github.com/dbooom/docker-compose-wp).

Based on the [official php:7-fpm docker image](https://hub.docker.com/_/php/)

## Environment variables

### Required variables:
| Variable Name          | Description         |
| ---                    | ---                 |
| `DWC_WP_ROOT`          | Directory where WordPress will be installed |
| `DWC_WP_HOME`          | WordPress WP_HOME constant |
| `DWC_WP_DB_NAME`       | Database name |
| `DWC_WP_DB_USER`       | Database user |
| `DWC_WP_DB_PASS`       | Database password |
| `DWC_WP_ADMIN_USER`    | WordPress administrator username |
| `DWC_WP_ADMIN_PASS`    | WordPress administrator user password |
| `DWC_WP_ADMIN_EMAIL`   | WordPress administrator email address |

### Optional variables:
| Variable Name               | Description         | Default value            |
| ---                         | ---                 | ---                      |
| `DWC_WP_DB_TABLE_PREFIX`    | Database tables prefix | `wp_` |
| `DWC_WP_DB_IMPORT_FILENAME` | Database dump filename to import instead of fresh database installation (directory containing this file must be mounted to container at `/database` path) | `none` |
| `DWC_WP_LANG`               | WordPress locale | `en_US` |
| `DWC_WP_VERSION`            | WordPress version to install | `latest` |
| `DWC_WP_PLUGINS`            | Additional plugins to install (plugin slugs separated with spaces) | `none` |
| `DWC_WP_THEME`              | Theme slug to install and activate with WordPress installation | `none` |
| `DWC_WP_DEBUG`              | Enables development oriented mode. [Details](#development-mode) | `false` |

### Extending entrypoint script:
If you need to add some steps to installation/configuration of WordPress process, you can mount additional shell script to `/user-entrypoint.sh` path. It will be included after everything is done, but the container's main process (php-fpm).

### Development mode:
- Set `DEBUG` and `SAVEQUERIES` WordPress constants to true,
- Alter PHP opcache directive (`opcache.revalidate_freq=0`),
- Install number of popular WordPress development plugins.
    - debug-bar
    - debug-bar-console
    - debug-bar-cron
    - debug-bar-extender
    - rewrite-rules-inspector
    - log-deprecated-notices
    - log-viewer
    - monster-widget
    - user-switching
    - rtl-tester
    - regenerate-thumbnails
    - simply-show-ids
    - theme-check
