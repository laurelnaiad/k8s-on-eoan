########################################################################

# gangway.sh

# https://github.com/heptiolabs/gangway/blob/master/docs/README.md
# https://blog.inkubate.io/access-your-kubernetes-cluster-with-your-active-directory-credentials/

########################################################################
MYDIR=$WORK_DIR/gangway
mkdir -p $MYDIR/heptiolabs-gangway
MY_SESSION_SECURITY_SECRET=session-security

kubectl create namespace gangway

kubectl create secret generic -n gangway $MY_SESSION_SECURITY_SECRET \
      --dry-run \
      --from-literal=sesssionkey=$(openssl rand -base64 32) \
      -o json \
  | kubeseal --cert $SSCERT \
  >$MYDIR/$MY_SESSION_SECURITY_SECRET.sealed.json
kubectl apply -f $MYDIR/$MY_SESSION_SECURITY_SECRET.sealed.json

mkdir -p $MYDIR/templates
cp $MYDIR/heptiolabs-gangway/templates/* $MYDIR/templates/
HISTCLEAR='history -d $(history 2); history -w'
cat $MYDIR/templates/commandline.tmpl \
  | awk -v HISTCLEAR="$HISTCLEAR" '{if(/^kubectl config set-context/) {print HISTCLEAR "\n" $0} else {print $0}}' \
  | tee $MYDIR/templates/commandline.tmpl
kubectl delete configmap -n gangway gangway-templates
kubectl create configmap -n gangway gangway-templates --from-file=$MYDIR/templates

read -r -d '' GANGWAY_YAML <<EOF
clusterName: "$CLUSTER_NAME"
authorizeURL: $DEX_ISSUER_URL/auth
tokenURL: $DEX_ISSUER_URL/token
audience: $DEX_ISSUER_URL/userinfo
redirectURL: $KEYS_APP_URL/callback
clientID: kubernetes
clientSecret: kubernetes-client-secret
usernameClaim: email
apiServerURL: https://$ADVERTISE_ADDR:6443
# customHTMLTemplatesDir: /gangway-templates
scopes: ["openid", "profile", "email", "groups", "offline_access"]
EOF
kubectl delete configmap -n gangway gangway
kubectl create configmap -n gangway gangway --from-literal gangway.yaml="$GANGWAY_YAML"

cat <<EOF > $MYDIR/config.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gangway
  namespace: gangway
  labels:
    app: gangway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gangway
  strategy:
  template:
    metadata:
      labels:
        app: gangway
        revision: "1"
    spec:
      containers:
        - name: gangway
          image: gcr.io/heptio-images/gangway:v3.2.0
          imagePullPolicy: IfNotPresent
          command: ["gangway", "-config", "/gangway/gangway.yaml"]
          env:

            - name: GANGWAY_SESSION_SECURITY_KEY
              valueFrom:
                secretKeyRef:
                  name: $MY_SESSION_SECURITY_SECRET
                  key: sesssionkey

            - { name: GANGWAY_SCOPES,   value: "openid,profile,email,groups,offline_access" }

            # Kubelet starts failing if the GANGWAY_PORT env var isn't set.
            # Seems to be a long story behind this bug. It's supposed to be the default.

            - { name: GANGWAY_PORT,     value: "8080" }

          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "200m"
              memory: "512Mi"
          volumeMounts:
            - name: gangway
              mountPath: /gangway
            - name: gangway-templates
              mountPath: /gangway-templates
          livenessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 20
            timeoutSeconds: 1
            periodSeconds: 60
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            timeoutSeconds: 1
            periodSeconds: 10
            failureThreshold: 3
      volumes:
        - name: gangway
          configMap:
            name: gangway
        - name: gangway-templates
          configMap:
            name: gangway-templates
---
kind: Service
apiVersion: v1
metadata:
  name: gangway
  namespace: gangway
  labels:
    app: gangway
spec:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 8080
  selector:
    app: gangway
---
kind: Ingress
apiVersion: networking.k8s.io/v1beta1
metadata:
  name: gangway
  namespace: gangway
  labels:
    app: gangway
  annotations:
    kubernetes.io/ingress.class: nginx-intranet
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: cert-issuer-prod
spec:
  rules:
  - host: $KEYS_APP_FQDN
    http:
      paths:
      - backend:
          serviceName: gangway
          servicePort: 8080
  tls:
  - hosts:
    - $KEYS_APP_FQDN
    secretName: $KEYS_APP_FQDN-tls
EOF
kubectl apply -f $MYDIR/config.yaml
kubectl rollout restart deployment -n gangway gangway
