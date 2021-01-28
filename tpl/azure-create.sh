#!/usr/bin/env bash
echo '#!/usr/bin/env bash'

subscription_id=$(y _ subscriptionId)
region=$(y _ region)
dns_resource_group=$(y dns resourceGroup)
aks_resource_group="otomi-aks-$CLUSTER"
cluster_name="$aks_resource_group"
appgw_rg="MC_${aks_resource_group}_${cluster_name}_${region}"
appgw_name="$cluster_name"
dns_sp_name="sp-dns-$cluster_name"
dns_zone=$(y dns zone)
certmanager_sp_name="sp-certmanager-$cluster_name"
years=5

echo "echo 'Changing account to use subscription \"$subscription_id\"'"
echo "az account set --subscription '$subscription_id'"

echo "echo 'Enabling feature Microsoft.ContainerService/AutoUpgradePreview'"
echo 'az feature register --namespace Microsoft.ContainerService -n AutoUpgradePreview'
echo 'az provider register -n Microsoft.ContainerService'
echo 'az extension add --name aks-preview'

echo 'if ! az group list | grep "\"name\": \"'$aks_resource_group'\"" >/dev/null; then'
  echo "  echo 'Creating Resource Group \"$aks_resource_group\"...'"
  echo "  az group create -n '$aks_resource_group' -l '$region'"
  echo "  echo 'Resource Group \"$aks_resource_group\" created'"
echo 'fi'

echo "echo 'Creating AKS cluster \"$cluster_name\". This will take around 10 minutes...'"

echo "az aks create -n '$cluster_name' -g '$aks_resource_group' --zones $(y _ zones)\
  $(y aks.create) $(y aks.nodePoolDefaults)\
  $(ye acr && echo --attach-acr $(y acr name))\
  $(ye appgw && echo "-a ingress-appgw --appgw-name $appgw_name --appgw-subnet-cidr $(y vnet appgwSubnetCIDR)")"

if ye appgw; then
  echo "echo 'Waiting for Application Gateway \"$appgw_name\"...'"
  echo 'while [ "$(az network application-gateway list -g '$appgw_rg' | grep "\"name\": \"'$appgw_name'\"")" = "" ]; do echo "sleeping 5" && sleep 5; done'
  
  echo "echo 'Updating Application Gateway \"$appgw_name\"...'"
  echo "az network application-gateway update -n $appgw_name -g $appgw_rg $(y appgw.update)"
  if y appgw.sslPolicy; then
    echo "az network application-gateway ssl-policy set --gateway-name $appgw_name -g $appgw_rg $(y appgw.sslPolicy)"
  fi

  if ye appgw.waf; then
    echo "echo 'Updating WAF settings for Application Gateway \"$appgw_name\"..."
    echo "az network application-gateway waf-config set -g $appgw_rg --gateway-name $appgw_name --enabled true $(y appgw.waf)"
  fi
fi

echo "echo 'Waiting for AKS cluster to become ready \"$cluster_name\"...'"
echo 'while [ "$(az aks list -g '$aks_resource_group' | grep "\"name\": \"'$cluster_name'\"")" = "" ]; do echo "sleeping 5" && sleep 5; done'

# if ya aks.additionalNodePools; then
#   echo 'echo' "Adding additional node pools to AKS cluster '$cluster_name'..."
#   echo 'echo' "Coming soon!"
# fi

if ye acr; then
  echo "echo 'Attaching pull rights to Azure Container Registry \"$(y acr name)\"..."
  echo 'kubeletIdentityObjectId=$(az aks show -n '$cluster_name' -g '$aks_resource_group' --query identityProfile.kubeletidentity.objectId --out tsv)'
  echo 'azureContainerRegistryId=$(az acr show -n '$(y acr name)' -g '$(y acr resourceGroup)' --query id --out tsv)'
  echo 'az role assignment create --role '$(y acr role)' --assignee-object-id $kubeletIdentityObjectId --scope $azureContainerRegistryId'
fi

if ye ad; then
  echo 'azure_dns_sp_appid=$(az ad sp list --display-name '$dns_sp_name' | jq -r ".[0].appId")'
  echo 'if [ "$azure_dns_sp_appid" = "null" ]; then'
    echo "  echo 'Creating the SP for Azure external-dns...'"
    echo '  dns_sp=$(az ad sp create-for-rbac -n '$dns_sp_name' --years '$years')'
    echo '  dns_sp_appid=$(echo $dns_sp | jq -r ".appId")'
    echo '  dns_sp_pw=$(echo $dns_sp | jq -r ".password")'
    echo "  echo 'Service Princial for Azure External DNS created'"
    echo "  echo 'Retrieving DNS Resource group ID'"
    echo '  dns_resource_group_id=$(az group show --name '$dns_resource_group' --query "id" --output tsv)'
    echo '  echo "The DNS Resource Group ID = $dns_resource_group_id"'
    echo "  echo 'Retrieving DNS Zone ID'"
    echo '  dns_zone_id=$(az network dns zone show --name '$dns_zone' --resource-group '$dns_resource_group' --query "id" --output tsv)'
    echo '  echo "The DNS Zone ID is \"$dns_zone_id\""'
    echo "  echo 'Creating role assignments for \"$dns_sp_name\"'"
    echo '  az role assignment create --role "Reader" --assignee $dns_sp_appid --scope $dns_resource_group_id'
    echo '  az role assignment create --role "Contributor" --assignee $dns_sp_appid --scope $dns_zone_id'
    echo "  echo 'Role assignments for \"$dns_sp_name\" created'"
    echo "  echo 'Creating yaml for external DNS'"
    echo '  cat <<EOF >>'$build_loc'/values.yaml
external-dns:
  azure:
    resourceGroup: '$dns_resource_group'
    aadClientId: $dns_sp_appid
    aadClientSecret: $dns_sp_pw
EOF'
  echo 'fi'

  echo 'azure_cert_sp_id=$(az ad sp list --display-name '$certmanager_sp_name' | jq -r ".[0].appId")'
  echo 'if [ "$azure_cert_sp_id" = "null" ]; then'
    echo "  echo 'Creating cert-manager service principal...'"
    echo '  azure_cert_manager_sp=$(az ad sp create-for-rbac --name '$certmanager_sp_name' --years '$years')'
    echo '  azure_cert_manager_sp_app_id=$(echo $azure_cert_manager_sp | jq -r ".appId")'
    echo '  azure_cert_manager_sp_password=$(echo $azure_cert_manager_sp | jq -r ".password")'
    echo "  echo 'Cert-manager service principal \"$certmanager_sp_name\" created'"
    echo "  echo 'Adding \"$certmanager_sp_name\" to DNS Zone Contributor role'"
    echo '  dns_id=$(az network dns zone show --name '$dns_zone' --resource-group '$dns_resource_group' --query "id" --output tsv)'
    echo '  az role assignment create --assignee $azure_cert_manager_sp_app_id --role "DNS Zone Contributor" --scope $dns_id'
    echo "  echo 'Role assignment for \"$certmanager_sp_name\" created'"
    echo "  echo 'Creating secret for cert-manager'"
    echo '  cat <<EOF >>'$build_loc'/values.yaml
cert-manager:
  provider:
    azuredns:
      clientID: $azure_cert_manager_sp_app_id
      clientSecret: $azure_cert_manager_sp_password
EOF
  fi'
fi

echo "echo 'Done creating AKS cluster \"$cluster_name\"'"