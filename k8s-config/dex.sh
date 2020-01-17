########################################################################

# dex.sh

########################################################################
MYDIR=$WORK_DIR/dex
mkdir -p $MYDIR
MYNS=dex
MYSECRETNAME=github-oauth2-client-creds

kubectl create namespace $MYNS

 kubectl create secret generic -n $MYNS $MYSECRETNAME \
    --dry-run \
    --from-literal=client-id=$GITHUB_OAUTH2_ID \
    --from-literal=client-secret=$GITHUB_OAUTH2_SECRET \
    --from-literal=cookie=$(openssl rand -hex 16) \
    -o json \
  | kubeseal --cert $SSCERT \
  >$MYDIR/$MYSECRETNAME.sealed.json
kubectl apply -f $MYDIR/$MYSECRETNAME.sealed.json
sleep 7 # give the sealed-secret a little time to be decrypted

cat <<YAML | tee $MYDIR/config.yaml
issuer: $DEX_ISSUER_URL
storage:
  type: kubernetes
  config:
    inCluster: true
web:
  http: 0.0.0.0:5556
connectors:
- type: github
  id: github
  name: GitHub
  config:
    clientID: \$GITHUB_CLIENT_ID
    clientSecret: \$GITHUB_CLIENT_SECRET
    redirectURI: $DEX_ISSUER_URL/callback
oauth2:
  skipApprovalScreen: true
staticClients:
- id: kubernetes
  redirectURIs:
  - $MY_GANGWAY_URL/callback
  name: kubernetes
  secret: kubernetes-client-secret
YAML

if [[ -n $GITHUB_ORG ]]
then
cat $MYDIR/config.yaml \
  | awk -v GHORG=$GITHUB_ORG '{if(/^oauth2:/) {print "  orgs:\n  - name: \"" GHORG "\"\n" $0} else {print $0}}' \
  | tee $MYDIR/config.yaml
else
cat $MYDIR/config.yaml \
  | awk '{if(/^oauth2:/) {print "  loadAllGroups: true\n" $0} else {print $0}}' \
  | tee $MYDIR/config.yaml
fi
kubectl delete configmap -n $MYNS dex
kubectl create configmap -n $MYNS dex  --from-file=$MYDIR/config.yaml

cat <<EOF | tee $MYDIR/dex-k8s-config.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: $MYNS
  labels:
    app: dex
  name: dex
spec:
  selector:
    matchLabels:
      app: dex
  replicas: 1
  template:
    metadata:
      labels:
        app: dex
    spec:
      serviceAccountName: dex
      containers:
      - image: quay.io/dexidp/dex:v2.21.0
        name: dex
        command: ["/usr/local/bin/dex", "serve", "/etc/dex/cfg/config.yaml"]
        ports:
        - name: http
          containerPort: 5556
        volumeMounts:
        - name: config
          mountPath: /etc/dex/cfg
        env:
        - name: GITHUB_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: $MYSECRETNAME
              key: client-id
        - name: GITHUB_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: $MYSECRETNAME
              key: client-secret
      volumes:
      - name: config
        configMap:
          name: dex
          items:
          - key: config.yaml
            path: config.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: $MYNS
  labels:
    app: dex
  name: dex
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: dex
rules:
- apiGroups: ["dex.coreos.com"] # API group created by dex
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["create"] # To manage its own resources, dex must be able to create customresourcedefinitions
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: dex
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dex
subjects:
- kind: ServiceAccount
  name: dex
  namespace: $MYNS
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: dex
  name: dex
  namespace: $MYNS
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 5556
    protocol: TCP
  selector:
    app: dex
---
kind: Ingress
apiVersion: networking.k8s.io/v1beta1
metadata:
  name: dex
  namespace: $MYNS
  labels:
    app: dex
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: cert-issuer-prod
spec:
  rules:
  - host: $DEX_ISSUER_FQDN
    http:
      paths:
      - backend:
          serviceName: dex
          servicePort: 5556
  tls:
  - hosts:
    - $DEX_ISSUER_FQDN
    secretName: dex-tls
EOF
kubectl apply -f $MYDIR/dex-k8s-config.yaml
kubectl rollout restart deployment -n $MYNS dex
