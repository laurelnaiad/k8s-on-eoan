function generate_reasonable_password() {
  echo $(openssl rand -base64 24 | sed 's/\//-/g')
}
