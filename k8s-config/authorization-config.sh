########################################################################

# authorization-config.sh

# https://ramitsurana.github.io/awesome-kubernetes/
# https://github.com/pusher/oauth2_proxy
# https://pusher.github.io/oauth2_proxy/auth-configuration
# https://thenewstack.io/single-sign-on-for-kubernetes-dashboard-experience/
# http://blog.cowger.us/2018/07/03/a-read-only-kubernetes-dashboard.html
# https://medium.com/@swade1987/part-2-sso-for-kubernetes-cli-43a518af0de8
# https://medium.com/@mrbobbytables/kubernetes-day-2-operations-authn-authz-with-oidc-and-a-little-help-from-keycloak-de4ea1bdbbe
# https://blog.inkubate.io/access-your-kubernetes-cluster-with-your-active-directory-credentials/
# https://itnext.io/protect-kubernetes-dashboard-with-openid-connect-104b9e75e39c
# https://www.tigera.io/blog/single-sign-on-for-kubernetes-the-command-line-experience/

########################################################################

MYDIR=$WORK_DIR/authorization-config
mkdir -p $WORK_DIR/authorization-config
cat <<EOF | tee $MYDIR/cluster-admin-svc-acct.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $CLUSTER_NAME-admin
  namespace: kube-system
EOF

cat <<EOF | tee $MYDIR/cluster-admin-role-binding.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $CLUSTER_NAME-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: $CLUSTER_NAME-admin
  namespace: kube-system
- kind: User
  name: $KUBE_ADMIN_USER
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f $MYDIR/cluster-admin-svc-acct.yml
kubectl apply -f $MYDIR/cluster-admin-role-binding.yml
