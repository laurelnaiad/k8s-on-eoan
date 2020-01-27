########################################################################

# default-ingress-backends.sh

########################################################################


kind: Certificate
metadata:
  name: $PRI_DOMAIN_DASH
  namespace: test-certs
spec:
  secretName: $PRI_DOMAIN_DASH-tls
  dnsNames:
  - "$PRI_DOMAIN"
  - "*.$PRI_DOMAIN"
  issuerRef:
    name: cert-issuer-staging
    kind: ClusterIssuer
    group: cert-manager.io
EOF

cat <<EOF > $MYDIR/intranet-cert.yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: intranet-$PRI_DOMAIN_DASH
  namespace: test-certs
spec:
  secretName: intranet-$PRI_DOMAIN_DASH-tls
  dnsNames:
  - "intranet.$PRI_DOMAIN"
  - "*.intranet.$PRI_DOMAIN"
  issuerRef:
    name: cert-issuer-staging
    kind: ClusterIssuer
    group: cert-manager.io
