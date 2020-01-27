function get_pod_name() {
  NS=$1
  DEPLOY_NAME=$2
  echo $(kubectl get pods -n $NS | awk '{print $1}' | grep $DEPLOY_NAME-)
}
