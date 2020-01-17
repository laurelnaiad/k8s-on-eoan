MYDIR=$WORK_DIR/dex-k8s-authenticator

git clone https://github.com/mintel/dex-k8s-authenticator $MYDIR

kubectl create namespace dex-k8s-authenticator

MYCACERT="$(sudo cat /etc/kubernetes/pki/ca.crt)"
# prepend 8 spaces to match yaml indentation
MYCACERT="$(echo "$MYCACERT" | sed -e 's/^/        /')"

cat <<EOF | tee $MYDIR/configmap.yaml
# Source: dex-k8s-authenticator/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dex-k8s-authenticator
  namespace: dex-k8s-authenticator
  labels:
    app: dex-k8s-authenticator
data:
  config.yaml: |-
    listen: http://0.0.0.0:5555
    web_path_prefix: /
    debug: false
    clusters:
    - client_id: kubernetes
      client_secret: kubernetes-client-secret
      issuer: $DEX_ISSUER_URL
      k8s_ca_pem: |
$MYCACERT
      k8s_master_uri: https://$ADVERTISE_ADDR:6443
      name: kubernetes
      redirect_uri: https://$KEYS_APP_HOST.$PRI_DOMAIN:443/callback
EOF
kubectl apply -f $MYDIR/configmap.yaml

cat <<EOF | tee $MYDIR/deployment.yaml
# Source: dex-k8s-authenticator/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dex-k8s-authenticator
  namespace: dex-k8s-authenticator
  labels:
    app: dex-k8s-authenticator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dex-k8s-authenticator
  template:
    metadata:
      labels:
        app: dex-k8s-authenticator
    spec:
      containers:
      - name: dex-k8s-authenticator
        image: "mintel/dex-k8s-authenticator:1.2.0"
        imagePullPolicy: IfNotPresent
        args: [ "--config", "config.yaml" ]
        ports:
        - name: http
          containerPort: 5555
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /healthz
            port: http
        readinessProbe:
          httpGet:
            path: /healthz
            port: http
        volumeMounts:
        - name: config
          subPath: config.yaml
          mountPath: /app/config.yaml
        resources:
          {}
      volumes:
      - name: config
        configMap:
          name: dex-k8s-authenticator
EOF
kubectl apply -f $MYDIR/deployment.yaml

cat <<EOF | tee $MYDIR/service.yaml
# Source: dex-k8s-authenticator/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: dex-k8s-authenticator
  namespace: dex-k8s-authenticator
  labels:
    app: dex-k8s-authenticator
spec:
  type: ClusterIP
  ports:
  - port: 5555
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: dex-k8s-authenticator
EOF
kubectl apply -f $MYDIR/service.yaml

cat <<EOF | tee $MYDIR/ingress.yaml
kind: Ingress
apiVersion: networking.k8s.io/v1beta1
metadata:
  name: dex-k8s-authenticator
  namespace: dex-k8s-authenticator
  labels:
    app: dex-k8s-authenticator
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: cert-issuer-prod
spec:
  rules:
  - host: $KEYS_APP_HOST.$PRI_DOMAIN
    http:
      paths:
      - backend:
          serviceName: dex-k8s-authenticator
          servicePort: 5555
  tls:
  - hosts:
    - $KEYS_APP_HOST.$PRI_DOMAIN
    secretName: $KEYS_APP_HOST-tls
EOF
kubectl apply -f $MYDIR/ingress.yaml
