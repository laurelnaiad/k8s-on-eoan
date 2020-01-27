function sleep_until_pod_ready() {
  NS=$1
  DEPLOY_NAME=$2
  INT_SECS=$3

  sleep 2
  until [ $(kubectl get pods --namespace $KNS \
      | awk "{if(/$DEPLOY_NAME-/) {print \$2}}" \
      | awk -F/ '{print $1}') -gt 0 ]
  do
    echo "`date +%r` -- waiting for $DEPLOY_NAME to be ready"
    sleep $INT_SECS
  done
}
