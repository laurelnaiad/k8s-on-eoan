########################################################################

# postgresql.sh

# https://www.bmc.com/blogs/kubernetes-postgresql/
# https://www.postgresql.org/docs/9.1/auth-pg-hba-conf.html
# https://doc.powerdns.com/authoritative/dnsupdate.html
# https://github.com/PowerDNS/pdns/blob/rel/auth-4.2.x/modules/gpgsqlbackend/schema.pgsql.sql
# https://doc.powerdns.com/authoritative/backends/generic-postgresql.html

# https://postgres-operator.readthedocs.io/en/latest/
# https://github.com/zalando/patroni

########################################################################
source "${0%/*}/../lib/all.sh"
MYDIR=$WORK_DIR/postgresql
KNS=postgres
mkdir -p $MYDIR

cat > $MYDIR/resources.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: initdb-scripts
  namespace: $KNS
data:
  set_hba.sh: |
    #!/bin/bash
    set -e
    cat > /var/lib/postgresql/data/pg_hba.conf

    cat > /var/lib/postgresql/data/pg_hba.conf <<EOF
    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    local   all             all                                     md5
    local   all             all                                     password
    host    all             all             127.0.0.1/32            md5
    host    all             all             ::1/128                 md5
    host    all             all             localhost               md5
    host    all             all             10.244.0.0/16           md5
    EOF
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: $KNS
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  volumeClaimTemplates:
  - metadata:
      name: postgresdb
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fixed-size
      resources:
        limits:
          storage: 1500Mi
        requests:
          storage: 800Mi
  template:
    metadata:
      labels:
        app: postgres
    spec:
      volumes:
      - name: initdb-scripts
        configMap:
          name: initdb-scripts
          defaultMode: 0777
      containers:
      - name: postgres
        image: postgres:12.1-alpine
        volumeMounts:
        - name: initdb-scripts
          mountPath: /docker-entrypoint-initdb.d
        - name: postgresdb
          mountPath: /var/lib/postgresql/data
        env:
        - name: POSTGRES_DB
          value: postgres
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          valueFrom: postgres
          valueFrom:
            secretKeyRef:
              name: postgresql-password
              key: postgresql-password
        ports:
        - containerPort: 5432
          name: postgres
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: $KNS
  labels:
    app: postgres
spec:
  type: ClusterIP
  ports:
  - port: 5432
    name: postgres
  selector:
    app: postgres
EOF


PASSWORD=$(generate_reasonable_password)
kubectl create namespace $KNS
sealed_secret_gen $SSCERT $KNS postgresql-password postgresql-password $PASSWORD \
    > $MYDIR/postgresql-password.sealed.json
kubectl apply -f $MYDIR/postgresql-password.sealed.json
kubectl apply -f $MYDIR/resources.yaml
sleep_until_pod_ready $KNS postgres 1
