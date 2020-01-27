DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/get-pod-name.sh

function kce_psql() {
  PGUSER=$1
  PGPASS=$2
  SQL_IN=$3

  POD=$(get_pod_name postgres postgres)

read -r -d '' SQL_OUT <<EOF2
 << EOF
$SQL_IN
EOF
EOF2

  kubectl exec -n postgres $POD -- sh -c "PGPASSWORD=$PGPASS exec psql --username $PGUSER $SQL_OUT"
}
