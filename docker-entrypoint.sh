#!/bin/bash

log() {
  yellow='\033[0;33m'
  nocolor='\033[0m'
  prefix="======>>  "
  suffix="  <<======"
  echo
  echo -e "${yellow}${prefix}${1}${suffix}${nocolor}"
  echo
}

APP_ENV=${APP_ENV:-$RAILS_ENV}
RAILS_ENV=${RAILS_ENV:-development}
APP_ENV=${APP_ENV:-$RAILS_ENV}
ENV_FILE=".env.$APP_ENV"

if [ ! -f $ENV_FILE ]; then
  echo "Missing ENV file: $ENV_FILE"
  exit 1
fi

ENV_VARS=$(sops -d $ENV_FILE 2> /dev/null)

if [[ "$?" != "0" ]]; then
  ENV_VARS=$(cat $ENV_FILE)
fi

export $(echo $ENV_VARS | xargs)

if [[ ! -v RAILS_ENV ]]; then
  export RAILS_ENV=$RAILS_ENV
fi

REQUIRED_ENV_VARS="
DATABASE_HOST
DATABASE_PORT
"

for v in $REQUIRED_ENV_VARS; do
  if [[ ! -v $v ]]; then
    echo "Missing required ENV VAR: '$v'"
    exit 1
  fi
done

/scripts/wait-for-it.sh $DATABASE_HOST:$DATABASE_PORT -t 30

if [ ! -z "$REDIS_HOST" ] && [ ! -z "$REDIS_PORT" ]; then
  /scripts/wait-for-it.sh $REDIS_HOST:$REDIS_PORT -t 30
fi

if [[ "$RAILS_ENV" == "development" ]]; then
  DOCKER_CMD=$(cat Dockerfile | grep CMD | awk '{ print $2 " " $3 " " $4 " " $5 " " $6 }')

  if [[ "$@" == "/bin/sh -c $DOCKER_CMD" ]]; then
    log "Running database migration"

    bundle exec rake db:migrate

    if [[ "$?" != 0 ]]; then
      log "Migration failed! Running databse setup"
      bundle exec rake db:setup
    fi

    if [ ! -z "$PROXY_HOST" ]; then
      /scripts/wait-for-it.sh $PROXY_HOST:80 -t 30

      export TRUSTED_IP=$(getent hosts $PROXY_HOST | awk '{ print $1 }')
    fi
  fi
fi

exec "$@"
