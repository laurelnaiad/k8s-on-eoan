########################################################################

# pod-security-policy.sh

# https://pmcgrath.net/using-pod-security-policies-with-kubeadm
# https://kubernetes.io/docs/concepts/policy/pod-security-policy/#policy-order

########################################################################

# no pods will be created until we establish a PodSecurityPolicy that allows them.
# based on https://github.com/kubernetes/website/raw/master/content/en/examples/policy/privileged-psp.yaml
cat <<EOF | tee $WORK_DIR/privileged-psp.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  # All other things equal, a PSP is selected by name-order. Rank this one
  # lastish so any more-intentional PSPs get applied to services when they exist.
  name: z-privileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
    seccomp.security.alpha.kubernetes.io/defaultProfileName:  'docker/default'
    apparmor.security.beta.kubernetes.io/defaultProfileName:  'runtime/default'
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
EOF
kubectl apply -f $WORK_DIR/privileged-psp.yaml

# a la https://pmcgrath.net/using-pod-security-policies-with-kubeadm

cat <<EOF | tee $WORK_DIR/privileged-psp-role-binding.yaml
# Cluster role which grants access to the default pod security policy
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: privileged-psp
rules:
- apiGroups:
  - policy
  resourceNames:
  - z-privileged
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
# Cluster role binding for default pod security policy granting all authenticated users access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: privileged-psp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: privileged-psp
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:nodes
  namespace: kube-system
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts:kube-system
EOF
kubectl apply -f $WORK_DIR/privileged-psp-role-binding.yaml


# default non-system policy

cat <<EOF | tee $WORK_DIR/default-psp.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  annotations:
    apparmor.security.beta.kubernetes.io/allowedProfileNames: 'runtime/default'
    apparmor.security.beta.kubernetes.io/defaultProfileName:  'runtime/default'
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'docker/default'
    seccomp.security.alpha.kubernetes.io/defaultProfileName:  'docker/default'
  name: z-default
spec:
  allowedCapabilities: []  # default set of capabilities are implicitly allowed
  allowPrivilegeEscalation: false
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  hostIPC: false
  hostNetwork: false
  hostPID: false
  privileged: false
  readOnlyRootFilesystem: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsNonRoot'
  supplementalGroups:
    rule: 'RunAsNonRoot'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  volumes:
  - 'configMap'
  - 'downwardAPI'
  - 'emptyDir'
  - 'persistentVolumeClaim'
  - 'projected'
  - 'secret'
  hostNetwork: false
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
EOF
kubectl apply -f $WORK_DIR/default-psp.yaml

cat <<EOF | tee $WORK_DIR/default-psp-role-binding.yaml
# Cluster role which grants access to the default pod security policy
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: default-psp
rules:
- apiGroups:
  - policy
  resourceNames:
  - z-default
  resources:
  - podsecuritypolicies
  verbs:
  - use

---
# Cluster role binding for default pod security policy granting all authenticated users access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: default-psp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: default-psp
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:authenticated
EOF
kubectl apply -f $WORK_DIR/default-psp-role-binding.yaml
