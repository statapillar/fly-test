#!/bin/sh

set -ex

if [ -n $MIGRATE_ON_BOOT ]; then
  $(dirname $0)/migrate.sh
fi


# node ./node_modules/.bin/redwood prisma generate
# ls
# ls ./node_modules
# ls ./node_modules/.bin/

node ./node_modules/.bin/rw-server --load-env-files
