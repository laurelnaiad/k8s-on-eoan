function sealed_secret_gen() {
  SSCERT=$1
  NS=$2
  SEC_NAME=$3
  SEC_KEY=$4
  SEC_VAL=$5

  echo $(kubectl create secret generic -n $NS $SEC_NAME \
      --dry-run \
      --from-literal=$SEC_KEY=$SEC_VAL \
      -o json \
  | kubeseal --cert $SSCERT)
}
