#!/usr/bin/env bash
set -e

source ./.env
. bin/common.sh
! check_env && exit 1

shopt -s expand_aliases
. bin/aliases

echo "Creating template for cluster $CLUSTER_NAME"
YAML_TMPL="/tmp/${CLUSTER_NAME}.yaml"
h template -f eni-max-pods.yaml -f values/default.yaml -f values/$CLUSTER_NAME.yaml \
  --set clusterName=$CLUSTER_NAME \
  --set region=$AWS_REGION \
  --set availabilityZones=$AWS_AZ \
  ./chart >$YAML_TMPL

[ ! -z ${1+x} ] && echo "dry run only, exiting..." && exit

set +e
chek=$(eksctl get cluster | grep "$CLUSTER_NAME")
set -e
if [ "$chek" = "" ]; then
  echo "Creating EKS cluster $CLUSTER_NAME"
  ec create cluster -f $YAML_TMPL
else
  echo "Updating EKS cluster $CLUSTER_NAME"
  ec upgrade cluster -f $YAML_TMPL
fi

echo "adding calico DeamonSet to support network policies"
# install Calico networking DeamonSet
k apply -f extras/calico/calico.yaml

# add users
bin/assign-users-to-cluster.sh
bin/rename-kube-context.sh

echo "All done!"
