function get_decode_secret_key_val() {
  NS=$1
  SEC_NAME=$2
  SEC_KEY=$3

  echo $(kubectl get secrets -n $NS $SEC_NAME -o yaml \
            | yq -r --arg SEC_KEY "$SEC_KEY" '. | .data[$SEC_KEY]' | base64 -d)
}
