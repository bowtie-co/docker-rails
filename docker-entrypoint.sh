#!/bin/bash

error() {
  red='\033[0;31m'
  nocolor='\033[0m'
  prefix="======>>  "
  suffix="  <<======"
  echo
  echo -e "${red}${prefix}${1}${suffix}${nocolor}"
  echo
}

log() {
  yellow='\033[0;33m'
  nocolor='\033[0m'
  prefix="======>>  "
  suffix="  <<======"
  echo
  echo -e "${yellow}${prefix}${1}${suffix}${nocolor}"
  echo
}

fail() {
  msg=${1:-Failure}
  code=${2:-1}

  error "FATAL: $msg"

  exit $code
}

has_env_var() {
  env | grep "$1" > /dev/null 2>&1
  return $?
}

missing_env_var() {
  if has_env_var $1; then
    return 1
  else
    return 0
  fi
}

RAILS_ENV=${RAILS_ENV:-development}
APP_ENV=${APP_ENV:-$RAILS_ENV}
ENV_FILE=".env.$APP_ENV"

if [ ! -f $ENV_FILE ]; then
  fail "Missing ENV file: $ENV_FILE"
fi

ENV_VARS=$(sops -d $ENV_FILE 2> /dev/null)

if [[ "$?" != "0" ]]; then
  ENV_VARS=$(cat $ENV_FILE)
fi

export $(echo $ENV_VARS | xargs)

if missing_env_var "RAILS_ENV"; then
  export RAILS_ENV=$APP_ENV
fi

REQUIRED_ENV_VARS="
RAILS_ENV
DATABASE_HOST
DATABASE_PORT
"

for v in $REQUIRED_ENV_VARS; do
  if missing_env_var "$v"; then
    fail "Missing required ENV VAR: '$v'"
  fi
done

/scripts/wait-for-it.sh $DATABASE_HOST:$DATABASE_PORT -t 30

if [ ! -z "$REDIS_HOST" ] && [ ! -z "$REDIS_PORT" ]; then
  /scripts/wait-for-it.sh $REDIS_HOST:$REDIS_PORT -t 30
fi

if [[ "$RAILS_ENV" == "development" ]] && [[ -f "Dockerfile" ]]; then
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
