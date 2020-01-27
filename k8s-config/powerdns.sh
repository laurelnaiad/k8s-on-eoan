########################################################################

# powerdns.sh

########################################################################
source "${0%/*}/../lib/all.sh"
MYDIR=$WORK_DIR/powerdns
KNS=powerdns
MY_BASE_IMG=buster-slim
mkdir -p $MYDIR

########################################################################
# configure postgres user and database
########################################################################
ROOT_PASS=$(get_decode_secret_key_val postgres postgresql-password postgresql-password)
PDNS_PASS=$(generate_reasonable_password)

read -r -d '' DDL <<EOF
create user powerdns with encrypted password '$PDNS_PASS';
create database powerdns with owner powerdns;
grant all privileges on database powerdns to powerdns;
EOF
kce_psql postgres $ROOT_PASS "$DDL"

DDL=$(curl https://raw.githubusercontent.com/PowerDNS/pdns/rec-4.1.6/modules/gpgsqlbackend/schema.pgsql.sql)
# (note, running as powerdns user, who will default to the powerdns database)
kce_psql powerdns $PDNS_PASS "$DDL"

########################################################################
# build powerdns image (if not already present)
########################################################################
kubectl delete namespace $KNS
sudo podman rmi localhost/powerdns:debian-$MY_BASE_IMG
if ! [[ $(sudo podman inspect localhost/powerdns:debian-$MY_BASE_IMG) ]]
then
cat > $MYDIR/entrypoint.sh <<'EOF'
#!/bin/bash

set -e
trap "pdns_control quit" SIGINT SIGTERM
pdns_server "$@" &
PID=$!
wait $PID
LAST=$?
echo "PowerDNS exited with code: $LAST"
exit $LAST
EOF
chmod 0755 $MYDIR/entrypoint.sh

cat > $MYDIR/pdns.conf <<EOF
launch=gpgsql
gpgsql-host=postgres.postgres
gpgsql-dbname=powerdns
gpgsql-user=powerdns
include-dir=/etc/powerdns/conf.d
EOF
# chmod 0600 $MYDIR/entrypoint.sh

cat > $MYDIR/Dockerfile <<EOF
FROM debian:$MY_BASE_IMG

RUN   apt-get update && \
      apt-get install -y --no-install-recommends pdns-server pdns-backend-pgsql && \
      rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /
COPY pdns.conf /etc/powerdns/

ENTRYPOINT [ "/entrypoint.sh" ]
EOF
sudo podman build -t localhost/powerdns:debian-$MY_BASE_IMG $MYDIR
fi

########################################################################
# configure powerdns k8s resources

# the multitude of services will be collapsible when/if
# https://github.com/kubernetes/kubernetes/pull/75831
# is merged
########################################################################
cat > $MYDIR/resources.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: powerdns
  name: powerdns
  namespace: $KNS
spec:
  ports:
  - name: api
    port: 8081
    protocol: TCP
    targetPort: 8081
  selector:
    app: powerdns
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    metallb.universe.tf/address-pool: intranet-dns
    external-dns.alpha.kubernetes.io/hostname: ns.intranet.$PRI_DOMAIN
  labels:
    app: powerdns
  name: powerdns-lb
  namespace: $KNS
spec:
  ports:
  - name: dns-udp
    port: 53
    protocol: UDP
    targetPort: 53
  selector:
    app: powerdns
  sessionAffinity: None
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: powerdns
  name: powerdns
  namespace: $KNS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: powerdns
  template:
    metadata:
      labels:
        app: powerdns
    spec:
      volumes:
      - name: powerdns-db-pass
        secret:
          secretName: powerdns-db-pass
      containers:
      - name: powerdns
        volumeMounts:
        - name: powerdns-db-pass
          readOnly: true
          mountPath: /etc/powerdns/conf.d
        image: localhost/powerdns:debian-$MY_BASE_IMG
        imagePullPolicy: IfNotPresent
        args:
        - --config-dir=/etc/powerdns
        - --setuid=pdns
        - --setgid=pdns
        - --api=yes
        - --api-key=\$(POWERDNS_API_KEY)
        - --cache-ttl=90
        - --disable-axfr=yes
        - --disable-syslog=yes
        - --do-ipv6-additional-processing=no
        - --guardian=yes
        - --loglevel=4
        - --master=yes
        - --version-string=anonymous
        - --webserver=yes
        - --webserver-address=0.0.0.0
        - --webserver-allow-from=127.0.0.0,::1,10.244.0.0/16
        env:
        - name: POWERDNS_API_KEY
          valueFrom:
            secretKeyRef:
              name: powerdns-api-key
              key: powerdns-api-key
        livenessProbe:
          httpGet:
            path: /
            port: api
        ports:
        - containerPort: 53
          name: dns-udp
          protocol: UDP
        - containerPort: 8081
          name: api
          protocol: TCP
        readinessProbe:
          httpGet:
            path: /
            port: api
EOF

########################################################################
# configure secrets
########################################################################
APIKEY=$(generate_reasonable_password)
sealed_secret_gen $SSCERT $KNS powerdns-api-key powerdns-api-key $APIKEY \
    > $MYDIR/powerdns-api-key.sealed.json
read -r -d '' SECVAL <<EOF
gpgsql-password=$PDNS_PASS
EOF
sealed_secret_gen $SSCERT $KNS powerdns-db-pass dbpass.conf "$SECVAL" \
    > $MYDIR/powerdns-db-pass.sealed.json

########################################################################
# deploy
########################################################################
kubectl delete namespace $KNS
kubectl create namespace $KNS
kubectl apply -f $MYDIR/powerdns-api-key.sealed.json
kubectl apply -f $MYDIR/powerdns-db-pass.sealed.json
kubectl apply -f $MYDIR/resources.yaml

sleep_until_pod_ready $KNS powerdns 1
kce_pdnsutil create-zone intranet.$PRI_DOMAIN ns.intranet.$PRI_DOMAIN
kce_pdnsutil add-record intranet.$PRI_DOMAIN ns A $INTRANET_DNS_IP
