DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/get-pod-name.sh

function kce_pdnsutil() {
  POD=$(get_pod_name powerdns powerdns)
  kubectl exec -n powerdns $POD -- sh -c "pdnsutil $*"
}
