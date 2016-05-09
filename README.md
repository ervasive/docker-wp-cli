# WordPress with WP-CLI Image

Install and configure WordPress dynamically, based on number of environment variables.

This image is meant to be used as a part of Docker Compose project and it doesn't include any database or web servers.
For more information about how to run this image go to the [project repo](https://github.com/dbooom/docker-compose-wp).

Based on the [official php:7-fpm docker image](https://hub.docker.com/_/php/)

## Environment variables

### Required variables:
| Variable Name     | Description         |
| ---               | ---                 |
| `MYSQL_HOSTNAME`  | Database container name |
| `MYSQL_DATABASE`  | Database name |
| `MYSQL_USER`      | Database user |
| `MYSQL_PASSWORD`  | Database password |
| `WP_HOME`         | WordPress WP_HOME constant |
| `WP_ADMIN_USER`   | WordPress administrator username |
| `WP_ADMIN_PASS`   | WordPress administrator user password |
| `WP_ADMIN_EMAIL`  | WordPress administrator email address |

### Optional variables:
| Variable Name     | Description         | Default value            |
| ---               | ---                 | ---                      |
| `WP_TABLE_PREFIX` | Database tables prefix | `wp_` |
| `WP_ROOT`         | Where WordPress should be installed | `/usr/share/nginx/html` |
| `WP_LANG`         | WordPress locale | `en_US` |
| `WP_VERSION`      | WordPress version to install | `latest` |
| `WP_DB_DUMP`      | Database dump filename to import instead of fresh database installation (directory containing this file must be mounted to container at `/database` path) | `none` |
| `WP_PLUGINS`      | Additional plugins to install (plugin slugs separated with spaces) | `none` |
| `WP_THEME`        | Theme slug to install and activate with WordPress installation | `none` |
| `WP_DEBUG`        | Enables development oriented mode. [Details](#development-mode) | `false` |

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
