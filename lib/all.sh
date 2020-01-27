#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $DIR/get-pod-name.sh
source $DIR/add-volume.sh
source $DIR/generate-reasonable-password.sh
source $DIR/get-decode-secret-key-val.sh
source $DIR/sealed-secret-gen.sh
source $DIR/sleep-until-pod-ready.sh
source $DIR/kce-psql.sh
source $DIR/kce-pdnsutil.sh
