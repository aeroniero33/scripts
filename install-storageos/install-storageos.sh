while read line
do
  export ETCD_HOST=$line
done < "${1:-/dev/stdin}"

echo "Installing StorageOS and ETCD"

curl -s https://raw.githubusercontent.com/aeroniero33/scripts/master/install-storageos/install-etcd.sh

SSH_USER="${SSH_USER:-root}"

scp ${SSH_USER}@${ETCD_HOST} -o StrictHostKeyChecking=no ./install-etcd.sh $ETCD_HOST:~/install-etcd.sh
echo ${ETCD_HOST} | ssh ${SSH_USER}@${ETCD_HOST} -o StrictHostKeyChecking=no bash install-etcd.sh

kubectl create -f https://github.com/storageos/cluster-operator/releases/download/v2.1.0/storageos-operator.yaml

kubectl create -f- <<END
apiVersion: v1
kind: Secret
metadata:
  name: "storageos-api"
  namespace: "storageos-operator"
  labels:
    app: "storageos"
type: "kubernetes.io/storageos"
data:
  # echo -n '<secret>' | base64
  apiUsername: c3RvcmFnZW9z
  apiPassword: c3RvcmFnZW9z
  # CSI Credentials
  csiProvisionUsername: c3RvcmFnZW9z
  csiProvisionPassword: c3RvcmFnZW9z
  csiControllerPublishUsername: c3RvcmFnZW9z
  csiControllerPublishPassword: c3RvcmFnZW9z
  csiNodePublishUsername: c3RvcmFnZW9z
  csiNodePublishPassword: c3RvcmFnZW9z
  csiControllerExpandUsername: c3RvcmFnZW9z
  csiControllerExpandPassword: c3RvcmFnZW9z
END

kubectl create -f- <<END
apiVersion: "storageos.com/v1"
kind: StorageOSCluster
metadata:
  name: "my-storageos-cluster"
  namespace: "storageos-operator"
spec:
  secretRefName: "storageos-api" # Reference from the Secret created in the previous step
  secretRefNamespace: "storageos-operator"  # Namespace of the Secret
  namespace: "kube-system"
  k8sDistro: "upstream"
  images:
    nodeContainer: "storageos/node:v2.1.0" # StorageOS version
  kvBackend:
    address: '${ETCD_HOST}:2379' # Example address, change for your etcd endpoint
  # address: '10.42.15.23:2379,10.42.12.22:2379,10.42.13.16:2379' # You can set ETCD server ips
  csi:
    enable: true
    deploymentStrategy: deployment
    enableControllerPublishCreds: true
    enableNodePublishCreds: true
    enableProvisionCreds: true
    enableControllerExpandCreds: true
  resources:
    requests:
    memory: "512Mi"
#  nodeSelectorTerms:
#    - matchExpressions:
#      - key: "node-role.kubernetes.io/worker" # Compute node label will vary according to your installation
#        operator: In
#        values:
#        - "true"
END
