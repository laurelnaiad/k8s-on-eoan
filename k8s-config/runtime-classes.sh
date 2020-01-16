########################################################################

# runtime-classes.sh

########################################################################
MYDIR=$WORK_DIR
cat <<EOF | tee $MYDIR/runtime-classes.yml
kind: RuntimeClass
apiVersion: node.k8s.io/v1beta1
metadata:
    name: runc
handler: runc
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1beta1
metadata:
    name: crun
handler: crun
EOF
kubectl apply -f $MYDIR/runtime-classes.yml
