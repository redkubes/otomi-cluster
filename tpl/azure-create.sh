#!/usr/bin/env bash
echo '#!/usr/bin/env bash'

echo "mkdir -p $build_loc_rel 2>/dev/null"
echo 'az config set core.only_show_errors=true'

# flags and helper strings:
preview=false
tid='--query id -o tsv'
out='--only-show-errors >/dev/null'
ye preview && preview=true
# config values:
# root
region=$(y _ region)
rg=$(y _ resourceGroup || echo otomi-aks-$CLUSTER)
cluster_name=$(y aks name || echo otomi-aks-$CLUSTER)
# derived
acr_name=$(y acr name)
aks_rg=$(y aks resourceGroup || echo $rg)
appgw_name="$cluster_name"
appgw_cidr=$(y vnet appgwSubnetCIDR || echo '')
certmanager_sp_name=$(y ad.sp certManager || echo sp-certmanager-$cluster_name)
cluster_rg="MC_${aks_rg}_${cluster_name}_${region}"
dns_rg=$(y dns resourceGroup)
dns_sp_name=$(y ad.sp externalDns || echo sp-externaldns-$cluster_name)
dns_zone=$(y dns zone)
ingress_ip_name=$(y sip ingress || echo "$cluster_name-ingress")
kms_rg=$(y kms resourceGroup || echo $rg)
kms_vault=$(y kms vault)
kms_sp_name=$(y ad.sp vault || echo sp-kms-$kms_vault)
kms_key=$(y kms key || echo otomi-values)
sip_rg=$(y sip resourceGroup || echo $rg)
storage_rg=$(y storage resourceGroup || echo $rg)
subscription_id=$(y _ subscriptionId)
vnet_subnet_id=$(y vnet.subnet id)
vnet_subnet_str=$([ -n "$vnet_subnet_id" ] && echo "--subnet '$vnet_subnet_id'")
years=5

echo 'user_id=$(az account show --query "user.name" -o tsv)'
echo 'echo Changing account to use subscription "'$subscription_id'"'
echo 'az account set --subscription "'$subscription_id'"'
echo

if $preview; then
  echo 'echo "Enabling feature Microsoft.ContainerService/AutoUpgradePreview"'
  echo 'az feature register --namespace Microsoft.ContainerService -n AutoUpgradePreview'
  echo 'az provider register -n Microsoft.ContainerService'
  echo 'az extension add --name aks-preview'
  echo
fi

echo 'if ! az group list | grep "\"name\": \"'$aks_rg'\"" >/dev/null; then'
echo '  echo "Creating AKS resource group '$aks_rg'..."'
echo '  az group create -n '$aks_rg' -l '$region $out
echo '  echo "Resource Group '$aks_rg' created"'
echo 'fi'
echo

echo 'dns_sp_id=$(az ad sp list --display-name '$dns_sp_name' | jq -r ".[0].appId")'
echo 'if [ "$dns_sp_id" = "null" ]; then'
echo '  echo "Creating the SP for Azure external-dns..."'
echo '  dns_sp=$(az ad sp create-for-rbac -n '$dns_sp_name' --years '$years $out')'
echo '  dns_sp_id=$(echo $dns_sp | jq -r ".appId")'
echo '  dns_sp_secret=$(echo $dns_sp | jq -r ".password")'
echo '  echo "Service principal for dns created"'
echo '  echo "Creating yaml for external-dns"'
echo '  cat <<EOF >>'$build_loc_rel'/values.yaml
external-dns:
  azure:
    resourceGroup: '$dns_rg'
    aadClientId: $dns_sp_id
    aadClientSecret: $dns_sp_secret
EOF'
echo 'fi'
echo
echo 'echo Retrieving DNS Resource group ID'
echo 'dns_rg_id=$(az group show --name '$dns_rg' --query id --output tsv 2>/dev/null)'
echo 'echo "The DNS Resource Group ID is $dns_rg_id"'
echo 'echo "Retrieving DNS Zone ID"'
echo 'dns_zone_id=$(az network dns zone show --name '$dns_zone' --resource-group '$dns_rg' --query id --output tsv)'
echo 'echo "The DNS Zone ID is $dns_zone_id"'
echo 'az role assignment create --role "Reader" --assignee $dns_sp_id --scope $dns_rg_id '$out
echo 'echo "Assigned role Reader to sp '$dns_sp_name' on scope $dns_rg_id"'
echo 'az role assignment create --role "Contributor" --assignee $dns_sp_id --scope $dns_zone_id '$out
echo 'echo "Assigned role Contributor to sp '$dns_sp_name' on scope $dns_zone_id"'
echo

echo 'certmanager_sp_id=$(az ad sp list --display-name '$certmanager_sp_name' | jq -r ".[0].appId")'
echo 'if [ "$certmanager_sp_id" = "null" ]; then'
echo '  echo "Creating the SP for cert-manager..."'
echo '  certmanager_sp=$(az ad sp create-for-rbac --name '$certmanager_sp_name' --years '$years $out')'
echo '  certmanager_sp_id=$(echo $certmanager_sp | jq -r ".appId")'
echo '  certmanager_sp_secret=$(echo $certmanager_sp | jq -r ".password")'
echo '  echo "Service principal for certmanager created"'
echo '  echo "Creating yaml for certmanager"'
echo '  cat <<EOF >>'$build_loc_rel'/values.yaml
cert-manager:
  provider:
    azuredns:
      resourceGroupName: '$dns_rg'
      clientID: $certmanager_sp_id
      clientSecret: $certmanager_sp_secret
EOF'
echo 'fi'
echo 'az role assignment create --assignee $certmanager_sp_id --role "DNS Zone Contributor" --scope $dns_zone_id '$out
echo 'echo "Assigned role DNS Zone Contributor to sp '$certmanager_sp_name' on scope $dns_zone_id"'
echo

echo 'kms_sp_id=$(az ad sp list --display-name '$kms_sp_name' | jq -r ".[0].appId")'
echo 'if [ "$kms_sp_id" = "null" ]; then'
echo '  echo "Creating the SP for Azure Key Vault..."'
echo '  kms_sp=$(az ad sp create-for-rbac -n '$kms_sp_name' --years '$years $out')'
echo '  kms_sp_id=$(echo $kms_sp | jq -r ".appId")'
echo '  kms_sp_secret=$(echo $kms_sp | jq -r ".password")'
echo '  echo "Service principal for Azure Key Vault created"'
echo '  cat <<EOF >>'$build_loc_rel'/values.yaml
kms:
  azure:
    resourceGroup: '$kms_rg'
    clientId: $kms_sp_id
    clientSecret: $kms_sp_secret
EOF'
echo "fi"
echo

echo 'ingress_ip_id=$(az network public-ip list --query "[?name=='"'"''$ingress_ip_name''"'"']".id -o tsv)'
echo 'if [ "$ingress_ip_id" = "" ]; then'
echo '  echo "Creating static ip address for ingress with name '$ingress_ip_name'"'
echo '  ingress_ip_addr=$(az network public-ip create -g '$sip_rg' -n '$ingress_ip_name' --allocation-method static --sku Standard $out | jq -r ".id")'
echo '  echo "Created static ip address for ingress: name='$ingress_ip_name', ip=$ingress_ip_addr"'
echo '  cat <<EOF >>'$build_loc_rel'/values.yaml
ingress-ip: $ingress_ip_addr
EOF'
echo 'fi'
echo 'ingress_ip="$(az network public-ip show -g '$sip_rg' -n '$ingress_ip_name')"'
echo 'ingress_ip_id=$(echo $ingress_ip  | jq -r ".id")'
echo 'ingress_ip_addr=$(echo $ingress_ip  | jq -r ".ipAddress")'
echo 'echo "We have the following static ip address for both ingress and egress: name='$ingress_ip_name', ip=$ingress_ip_addr"'
echo

echo 'msi=$(az identity show -n "'$cluster_name'" -g "'$aks_rg'" '$tid' 2>/dev/null)'
echo 'if [ -z "$msi" ]; then'
echo '  echo "Creating AKS MSI '$cluster_name'"'
echo '  msi=$(az identity create -n "'$cluster_name'" -g "'$aks_rg'" -l "'$region'" '$tid $out')'
echo 'fi'
echo 'msi_client_id=$(az identity show --query clientId -o tsv --id $msi)'
echo 'echo "Granting Network Contributor access to the msi SP to manage the static ingress ip..."'
echo 'az role assignment create --assignee "$msi_client_id" --scope "$ingress_ip_id" --role "Network Contributor" '$out
if [ -n "$vnet_subnet_id" ]; then
  echo 'az role assignment create --assignee "$msi_client_id" --scope "'$vnet_subnet_id'" --role "Network Contributor" '$out
fi
echo

if ye appgw && ! $preview; then
  echo 'appgw_id=$(az aks network application-gateway show -n "'$appgw_name'" -g "'$aks_rg $tid' 2>/dev/null")'
  echo 'if [ -z "$appgw_id" ]; then'
  echo '  echo "Creating Application Gateway '$appgw_name'. This will take around 10 minutes..."'
  echo '  az aks network application-gateway create -n '$appgw_name' -g '$aks_rg' $vnet_subnet_str --zones $(y _ zones) $(y appgw.create) --public-ip-address '\$ingress_ip_addr $out
  echo 'fi'
  echo
fi

if ye kms; then
  echo 'keyvault_id=$(az keyvault show -n "'$kms_vault'" -g "'$kms_rg'" '$tid' 2>/dev/null)'
  echo 'if [ -z "$keyvault_id" ]; then'
  echo '  echo "Creating keyvault '$kms_vault'"'
  echo '  keyvault_id=$(az keyvault create --name "'$kms_vault'" --resource-group "'$kms_rg'" --enable-purge-protection --enable-rbac-authorization '$tid $out')'
  echo 'fi'
  echo 'kms_key_id=$(az keyvault key show -n "'$kms_key'" -g "'$kms_rg'" '$tid' 2>/dev/null)'
  echo 'if [ -z "$kms_key_id" ]; then'
  echo '  echo "Creating key '$kms_key'"'
  echo '  kms_key_id=$(az keyvault key create --name "'$kms_key'" --vault-name "'$kms_vault'" --protection software --ops encrypt decrypt --query key.kid '$out')'
  echo 'fi'
  echo 'az role assignment create --role "Key Vault Administrator" --assignee "$user_id" --scope "$keyvault_id" '$out
  echo 'sleep 5'
  echo 'az role assignment create --role "Key Vault Crypto Service Encryption User" --assignee "$kms_sp_id" --scope "$keyvault_id/keys/'$kms_key'" '$out
  echo 'sleep 5'
  echo 'echo "Created key vault '$kms_vault', with key '$kms_key' (key ID $kms_key_id)"'
  echo
fi

echo 'echo "Creating AKS cluster '$cluster_name'. This will take around 10 minutes..."'
echo 'az aks create -n '$cluster_name' -g '$aks_rg $([ -n "$vnet_subnet_id" ] && echo "--vnet-subnet-id '$vnet_subnet_id'")' --assign-identity "$msi" --zones '$(y _ zones)' --load-balancer-outbound-ips "$ingress_ip_id" '$(y aks.create) $(y aks.nodePoolDefaults) $(ye acr && echo "--attach-acr $acr_name") $(ye appgw && $preview && echo "-a ingress-appgw --appgw-name '$appgw_name'") $(ye appgw && $preview && [ -n "$appgw_cidr" ] && echo "--appgw-subnet-cidr '$appgw_cidr'") $out
echo

if ye appgw; then
  echo 'echo "Waiting for Application Gateway '$appgw_name'..."'
  echo 'while [ "$(az network application-gateway list -g '$cluster_rg' | grep "\"name\": \"'$appgw_name'\"")" = "" ]; do echo "sleeping 5" && sleep 5; done'

  echo 'echo "Updating Application Gateway '$appgw_name'..."'
  echo 'az network application-gateway update -n '$appgw_name' -g '$cluster_rg $(y appgw.update)
  if y appgw.sslPolicy; then
    echo 'az network application-gateway ssl-policy set --gateway-name '$appgw_name' -g '$cluster_rg $(y appgw.sslPolicy)
  fi

  if ye appgw.waf; then
    echo 'echo "Updating WAF settings for Application Gateway '$appgw_name'..."'
    echo 'az network application-gateway waf-config set -g '$cluster_rg' --gateway-name '$appgw_name' --enabled true '$(y appgw.waf)
  fi
  echo
fi

echo 'echo "Waiting for AKS cluster '$cluster_name' to become ready..."'
echo 'while [ "$(az aks list -g '$aks_rg' | grep "\"name\": \"'$cluster_name'\"")" = "" ]; do echo "sleeping 5" && sleep 5; done'
echo
# if ya aks.additionalNodePools; then
#   echo 'echo' "Adding additional node pools to AKS cluster '$cluster_name'..."
#   echo 'echo' "Coming soon!"
# fi

if ye acr; then
  echo 'echo Attaching pull rights to Azure Container Registry "'$acr_name'"...'
  echo 'kubelet_identity_object_id=$(az aks show -n '$cluster_name' -g '$aks_rg' --query servicePrincipalProfile.clientId -o tsv)'
  echo '[ "$kubelet_identity_object_id" = "msi" ] && kubelet_identity_object_id=$(az aks show -n '$cluster_name' -g '$aks_rg' --query identityProfile.kubeletidentity.objectId -o tsv)'
  echo 'azure_container_registry_id=$(az acr show -n '$acr_name' -g '$(y acr resourceGroup)' --query id --out tsv)'
  echo 'az role assignment create --role '$(y acr role)' --assignee-object-id $kubelet_identity_object_id --scope $azure_container_registry_id '$out
  echo
fi

if ye db.postgres; then
  names=$(y db.postgres names)
  for name in $names; do
    id="db_id_$(echo $name | sed -e 's/-/_/g')"
    echo $id'=$(az postgres server show -n '$name' -g '$aks_rg $tid' 2>/dev/null)'
    echo 'if [ -z "$'$id'" ]; then'
    echo '  echo Creating database: "'$name'"'
    echo '  '$id'=$(az postgres server create -n '$name' -g '$aks_rg $(y db.postgres.$name.create) $tid $out')'
    echo 'fi'
    echo 'echo Creating firewall rules for db "'$name'"'
    echo 'az postgres server firewall-rule create -n '$name' -g '$aks_rg' --server-name '$name' --start-ip-address "$ingress_ip_addr" --end-ip-address "$ingress_ip_addr" '$out
    for ip_addr in $(y db.postgres.$name ipAccess 1); do
      ip_label=$(echo $ip_addr | sed -e 's/\./-/g')
      echo 'az postgres server firewall-rule create -n '$name-$ip_label' -g '$aks_rg' --server-name '$name' --start-ip-address '$ip_addr' --end-ip-address '$ip_addr $out
    done
    echo
    if ye db.postgres.privateEndpoint; then
      echo 'echo Creating private endpoint "'$name-postgres'"'
      echo 'az network private-endpoint create -g '$aks_rg' --connection-name '$name-postgres-connection' --name '$name-postgres' --private-connection-resource-id "$'$id'" --location '$region' --group-id postgresqlServer '$vnet_subnet_str $out
      echo 'if [ -z "$(az network private-dns zone show -g '$aks_rg' -n "privatelink.postgres.database.azure.com")" ]; then'
      echo '  echo Setting up private dns zone and private link for postgres'
      echo '  az network private-dns zone create -g '$aks_rg' -n "privatelink.postgres.database.azure.com" '$out
      echo '  az network private-dns link vnet create -g '$aks_rg' --zone-name "postgres.database.azure.com" -n "otomi-storage" --virtual-network "'$vnet_subnet_id'" --registration-enabled false '$out
      echo '  az network private-endpoint dns-zone-group create -g '$aks_rg' -n "otomi-storage" --zone-name "postgres.database.azure.com" --endpoint-name "otomi-storage" --private-dns-zone "postgres.database.azure.com" '$out
      echo 'fi'
      echo
    fi
  done
fi

if ye storage; then
  storage_account_name="otomi$CLUSTER"
  echo 'storage_account_id=$(az storage account show -n '$storage_account_name' -g '$storage_rg $tid')'
  echo 'if [ -z "$storage_account_id" ]; then'
  echo '  storage_account_id=$(az storage account create -n '$storage_account_name' -g '$storage_rg $(y storage.create)' --default-action Deny '$subnet $tid $out')'
  echo '  export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n '$storage_account_name' -g '$aks_rg' -o tsv)'
  echo '  storage_key=$(az storage account keys list --resource-group '$storage_rg' --account-name '$storage_account_name' --query "[0].value" -o tsv)'
  echo '  echo "Creating yaml for storage"'
  echo '  cat <<EOF >>'$build_loc_rel'/values.yaml
storage-'$storage_account_name':
  resourceGroup: '$storage_rg'
  accountName: '$storage_account_name'
  accountKey: $storage_key
EOF'
  echo 'fi'
  echo 'export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n '$storage_account_name' -g '$aks_rg' -o tsv)'
  echo 'az role assignment create --role "Storage Blob Data Contributor" --assignee "$user_id" --scope "$storage_account_id" '$out
  echo 'echo "Assigned role Storage Blob Data Contributor to SP $user_id on scope $storage_account_id"'
  if ye storage.privateEndpoint; then
    echo 'echo "Creating private endpoint 'otomi-storage'"'
    echo 'az network private-endpoint create -g '$aks_rg' --connection-name otomi-storage-connection --name otomi-storage --private-connection-resource-id "$storage_account_id" --location '$region' --group-id blob '$vnet_subnet_str $out
    echo
    echo 'echo "Setting up private dns zone for storage"'
    echo 'if [ -z "$(az network private-dns zone show -g '$aks_rg' -n "privatelink.blob.core.windows.net" 2>/dev/null)" ]; then'
    echo '  az network private-dns zone create -g '$aks_rg' -n "privatelink.blob.core.windows.net" '$out
    echo '  az network private-dns link vnet create -g '$aks_rg' --zone-name "privatelink.blob.core.windows.net" -n "otomi-storage" --virtual-network "'$vnet_subnet_id'" --registration-enabled false '$out
    echo '  az network private-endpoint dns-zone-group create -g '$aks_rg' -n "otomi-storage" --zone-name "privatelink.blob.core.windows.net" --endpoint-name "otomi-storage" --private-dns-zone "privatelink.blob.core.windows.net" '$out
    echo 'fi'
    echo
  fi
  if ye storage.containers; then
    echo 'az storage account network-rule add --account-name '$storage_account_name' -g '$storage_rg' --ip-address $(curl ifconfig.co)'
    echo 'sleep 10'
    names=$(y storage.containers names)
    for name in $names; do
      id="container_id_$(echo $name | sed -e 's/-/_/g')"
      echo $id'=$(az storage container show -n '$name $tid')'
      echo 'if [ -z "$'$id'" ]; then'
      echo '  echo Creating storage container '$name
      echo '  '$id'=$(az storage container create -n '$name $tid $out')'
      echo 'fi'
    done
    echo 'az storage account network-rule remove --account-name '$storage_account_name' -g '$storage_rg' --ip-address $(curl ifconfig.co)'
    echo
  fi
fi

echo 'echo "Done creating AKS resources for cluster '$cluster_name'"'
echo
echo 'echo "Saving the kubeconfig for the cluster to '$build_loc_rel'/kubeconfig.yaml"'
echo 'az aks get-credentials -g '$aks_rg' -n '$cluster_name' --admin -f '$build_loc_rel'/kubeconfig.yaml'
