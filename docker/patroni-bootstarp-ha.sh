#!/bin/bash

# Copyright 2019 - 2021 Crunchy Data Solutions, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set_default_patroni_env() {

    host_ip=$(hostname -i)

    if [[ ! -v PATRONI_NAME ]]
    then
        export PATRONI_NAME="${HOSTNAME}"
        default_patroni_env_vars+=("PATRONI_NAME")
    fi

    if [[ ! -v PATRONI_SCOPE ]]
    then
        export PATRONI_SCOPE="example-cluster"
        default_patroni_env_vars+=("PATRONI_SCOPE")
    fi

    if [[ ! -v PATRONI_RESTAPI_LISTEN ]]
    then
        export PATRONI_RESTAPI_LISTEN="0.0.0.0:${PGHA_PATRONI_PORT}"
        default_patroni_env_vars+=("PATRONI_RESTAPI_LISTEN")
    fi

    if [[ ! -v PATRONI_RESTAPI_CONNECT_ADDRESS ]]
    then
        export PATRONI_RESTAPI_CONNECT_ADDRESS="${host_ip}:${PGHA_PATRONI_PORT}"
        default_patroni_env_vars+=("PATRONI_RESTAPI_CONNECT_ADDRESS")
    fi

    if [[ ! -v PATRONI_POSTGRESQL_LISTEN ]]
    then
        export PATRONI_POSTGRESQL_LISTEN="0.0.0.0:${PGHA_PG_PORT}"
        default_patroni_env_vars+=("PATRONI_POSTGRESQL_LISTEN")
    fi

    if [[ ! -v PATRONI_POSTGRESQL_CONNECT_ADDRESS ]]
    then
        export PATRONI_POSTGRESQL_CONNECT_ADDRESS="${host_ip}:${PGHA_PG_PORT}"
        default_patroni_env_vars+=("PATRONI_POSTGRESQL_CONNECT_ADDRESS")
    fi

    if [[ ! -v PATRONI_POSTGRESQL_DATA_DIR ]]
    then
        export PATRONI_POSTGRESQL_DATA_DIR="/var/lib/opengauss/data/${HOSTNAME}"
        default_patroni_env_vars+=("PATRONI_POSTGRESQL_DATA_DIR")
    fi

    if [[ ! -v PATRONI_POSTGRESQL_REPLCONN ]]
    then
        export PATRONI_POSTGRESQL_REPLCONN="/etc/patroni/replconn/replconninfo"
        default_patroni_env_vars+=("PATRONI_POSTGRESQL_REPLCONN")
    fi

    if [[ ! -v PATRONI_CONFIG_FILE ]]
    then
        export PATRONI_CONFIG_FILE="/etc/patroni/patroni-bootstrap.yaml"
        default_patroni_env_vars+=("PATRONI_CONFIG_FILE")
    fi

    if [[ ! ${#default_patroni_env_vars[@]} -eq 0 ]]
    then
        pgha_env_vars=$(printf ', %s' "${default_patroni_env_vars[@]}")
        echo "Defaults have been set for the following Patroni env vars: ${pgha_env_vars:2}"
    fi
}

set_default_pgha_env() {

    if [[ ! -v PGHA_PATRONI_PORT ]]
    then
        export PGHA_PATRONI_PORT="8008"
        default_pgha_env_vars+=("PGHA_PATRONI_PORT")
    fi

    if [[ ! -v PGHA_PG_PORT ]]
    then
        export PGHA_PG_PORT="5432"
        default_pgha_env_vars+=("PGHA_PG_PORT")
    fi

    if [[ ! -v PGHA_DATABASE ]]
    then
        export PGHA_DATABASE="userdb"
        default_pgha_env_vars+=("PGHA_DATABASE")
    fi

    if [[ ! -v PGHA_REPLICA_REINIT_ON_START_FAIL ]]
    then
        export PGHA_REPLICA_REINIT_ON_START_FAIL="true"
        pgha_env_vars+=("PGHA_REPLICA_REINIT_ON_START_FAIL")
    fi

    if [[ ! ${#default_pgha_env_vars[@]} -eq 0 ]]
    then
        pgha_env_vars=$(printf ', %s' "${default_pgha_env_vars[@]}")
        echo "Defaults have been set for the following postgres-ha env vars: ${pgha_env_vars:2}"
    fi
}

build_bootstrap_config_file() {
  echo "Starting to build bootstrap config file"
  bootstrap_file="/tmp/config/postgres-ha-bootstrap.yaml"
  patroni_file="${PATRONI_CONFIG_FILE}"
  if [[ -f "${patroni_file}" ]]
  then
    echo "merge patroni_file to bootstrap_file"
    yq m -i -x "${bootstrap_file}" "${patroni_file}"
  else
    echo "not found ${patroni_file})"
  fi
}

#reload_replconn_conf() {
#    echo "Starting to reload replconninfo conf"
#
#    # wait for postgres running
#    status_code=$(curl -o /dev/stderr -w "%{http_code}" "127.0.0.1:${PGHA_PATRONI_PORT}/health" 2> /dev/null)
#    until [[ "${status_code}" == "200" ]]
#    do
#        sleep 1
#        echo "Cluster not yet started, retrying" >> "/tmp/replconninfo_running_check.log"
#        status_code=$(curl -o /dev/stderr -w "%{http_code}" "127.0.0.1:${PGHA_PATRONI_PORT}/health" 2> /dev/null)
#    done
#
#    host_ip=$(hostname -i)
#    bootstrap_file="/tmp/config/postgres-ha-bootstrap.yaml"
#    pg_conn_conf="/tmp/postgres.replconn.conf"
#    replconninfo=
#    i=1
#    conn_file="${PATRONI_POSTGRESQL_REPLCONN}"
#
#    while IFS= read -r line
#    do
#        if [[ -n $line ]] && ! [[ $line == "$host_ip" ]]
#        then
#            printf -v replconnKey "replconninfo%s" "$i"
#            printf -v replconnValue "localhost=%s localport=5433 localheartbeatport=26002 localservice=26003 remotehost=%s remoteport=5433 remoteheartbeatport=26002 remoteservice=26003" "$host_ip" "$line"
#            yq w -i "${bootstrap_file}" "postgresql.parameters.${replconnKey}" "${replconnValue}"
#            printf -v replconninfo "%s%s='%s'\n" "$replconninfo" "$replconnKey" "$replconnValue"
#            ((i=i+1))
#        fi
#    done < "$conn_file"
#
#    if [[ -f "$pg_conn_conf" ]]
#    then
#        if echo -n "$replconninfo" | diff $pg_conn_conf - >/dev/null
#        then
#            echo "No changes in replconn conf, skipping"
#            return 0
#        fi
#    fi
#    echo -n "$replconninfo" > "$pg_conn_conf"
#    echo "New postgres replconninfo conf has been written"
#
#    curl -s -XPOST "http://127.0.0.1:${PGHA_PATRONI_PORT}/reload"
#    echo "Postgresql replconninfo conf reloaded"
#}

#replconninfo_monitor() {
#    echo "Starting background process to monitor replica connection info and reload conf"
#    {
#        reload_replconn_conf
#
#        inotifywait -e moved_to -qm ${conn_file%/*} |
#        while read -r directory events filename; do
#            echo "Replconninfo File may changed:${directory} ${events} ${filename}"
#            sleep 3
#            reload_replconn_conf
#        done
#    } &
#}

remove_ssl_file() {
    echo "remove ssl file"
    target_server_path="/tmp/opengauss/cluster-certs"
    target_client_path="/tmp/opengauss/client-certs"
    source_server_path="/opt/opengauss/cluster-certs"
    source_client_path="/opt/opengauss/client-certs"

    if [[ -f "$source_server_path" ]] && [[ -f "$source_client_path" ]]
    then
      echo "mv ssl certs"
      install -D --mode=0600 -t "$target_client_path" "$source_client_path"{/ca.crt,/repl.crt,/repl.key}
      install -D --mode=0600 -t "$target_server_path" "$source_server_path"{/ca.crt,/cluster.crt,/cluster.key}
      echo "mv ssl certs success"
    fi
}

set_default_pgha_env

set_default_patroni_env

build_bootstrap_config_file

remove_ssl_file

tini --  ./patroni /tmp/config/postgres-ha-bootstrap.yaml
