########################################################################

# nginx-default-backend.sh

# https://kubernetes.github.io/ingress-nginx/deploy/

# TODO: fixme -- this doesn't work once ssl is enabled – need to be doing this
# after getting cert-manager configured and when a wildcard certificate has been
# installed.

########################################################################

# https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/customization/custom-errors
kubectl apply -n ingress-nginx -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/docs/examples/customization/custom-errors/custom-default-backend.yaml
# adding  --publish-service=$(POD_NAMESPACE)/ingress-nginx as per
# https://github.com/danderson/metallb/issues/260#issuecomment-470520168 and
# https://kubernetes.github.io/ingress-nginx/user-guide/cli-arguments/ with assist from
# https://github.com/helm/charts/blob/a37e4432b5c31bef9773d69a537f2aa26de0ee82/stable/nginx-ingress/templates/controller-deployment.yaml#L54
MY_PATCH='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["/nginx-ingress-controller", "--configmap=$(POD_NAMESPACE)/nginx-configuration", "--tcp-services-configmap=$(POD_NAMESPACE)/tcp-services", "--udp-services-configmap=$(POD_NAMESPACE)/udp-services", "--publish-service=$(POD_NAMESPACE)/ingress-nginx", "--annotations-prefix=nginx.ingress.kubernetes.io", "--default-backend-service=$(POD_NAMESPACE)/nginx-errors"] }]'
kubectl patch -n ingress-nginx deployment/nginx-ingress-controller --type=json -p="$MY_PATCH"
kubectl patch -n ingress-nginx configmap/nginx-configuration --type merge -p='{ "data": { "custom-http-errors": "404,503" }}'
kubectl rollout restart -n ingress-nginx deploy/nginx-ingress-controller
