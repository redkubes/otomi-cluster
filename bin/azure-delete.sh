#!/usr/bin/env bash
set -e
. bin/common.sh

! check_env && exit 1

echo "Deleting all resources in Resource Group $AZURE_RESOURCE_GROUP"

az group delete --name $AZURE_RESOURCE_GROUP

AZURE_INGRESS_SP_APPID=$(az ad sp list --display-name $AZURE_INGRESS_SP_NAME | jq -r '.[0].appId')
if [ "$AZURE_INGRESS_SP_APPID" != "null" ]; then
  az ad sp delete --id $AZURE_INGRESS_SP_APPID
fi

AZURE_DNS_SP_APPID=$(az ad sp list --display-name $AZURE_EXTERNALDNS_SP_NAME | jq -r '.[0].appId')
if [ "$AZURE_DNS_SP_APPID" != "null" ]; then
  az ad sp delete --id $AZURE_DNS_SP_APPID
fi

AZURE_CERT_SP_ID=$(az ad sp list --display-name $AZURE_CERT_MANAGER_SP_NAME | jq -r '.[0].appId')
if [ "$AZURE_CERT_SP_ID" != "null" ]; then
  az ad sp delete --id $AZURE_CERT_SP_ID
fi

echo "DONE!"