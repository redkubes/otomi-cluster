#!/usr/bin/env bash
echo '#!/usr/bin/env bash'

preview=false
ye preview && preview=true

subscription_id=$(y _ subscriptionId)
region=$(y _ region)
dns_rg=$(y dns resourceGroup)
aks_rg="otomi-aks-$CLUSTER"
cluster_name="$aks_rg"
appgw_rg="MC_${aks_rg}_${cluster_name}_${region}"
appgw_name="$cluster_name"
certmanager_sp_name=$(y ad.sp certManager || echo sp-certmanager-$cluster_name)
dns_sp_name=$(y ad.sp externalDns || echo sp-externaldns-$cluster_name)
dns_zone=$(y dns zone)
kms_rg=$(y kms resourceGroup)
kms_vault=$(y kms vault)
kms_sp_name=$(y ad.sp vault || echo sp-kms-$kms_vault)
kms_key=$(y kms key || echo otomi-values)
years=5

echo "echo 'Changing account to use subscription \"$subscription_id\"'"
echo "az account set --subscription '$subscription_id'"

if $preview; then
  echo "echo 'Enabling feature Microsoft.ContainerService/AutoUpgradePreview'"
  echo 'az feature register --namespace Microsoft.ContainerService -n AutoUpgradePreview'
  echo 'az provider register -n Microsoft.ContainerService'
  echo 'az extension add --name aks-preview'
fi

echo 'if ! az group list | grep "\"name\": \"'$aks_rg'\"" >/dev/null; then'
echo "  echo 'Creating Resource Group \"$aks_rg\"...'"
echo "  az group create -n '$aks_rg' -l '$region'"
echo "  echo 'Resource Group \"$aks_rg\" created'"
echo 'fi'

echo 'dns_sp_id=$(az ad sp list --display-name '$dns_sp_name' | jq -r ".[0].appId")'
echo 'if [ "$dns_sp_id" = "null" ]; then'
echo "  echo 'Creating the SP for Azure external-dns...'"
echo '  dns_sp=$(az ad sp create-for-rbac -n '$dns_sp_name' --years '$years')'
echo '  dns_sp_id=$(echo $dns_sp | jq -r ".appId")'
echo '  dns_sp_secret=$(echo $dns_sp | jq -r ".password")'
echo "  echo 'Service principal for external-dns created'"
echo "  echo 'Creating yaml for external DNS'"
echo '  cat <<EOF >>'$build_loc'/values.yaml
external-dns:
  azure:
    resourceGroup: '$dns_rg'
    aadClientId: $dns_sp_id
    aadClientSecret: $dns_sp_secret
EOF'
echo 'fi'
echo "echo 'Retrieving DNS Resource group ID'"
echo 'dns_rg_id=$(az group show --name '$dns_rg' --query "id" --output tsv)'
echo 'echo "The DNS Resource Group ID = \"$dns_rg_id\""'
echo "echo 'Retrieving DNS Zone ID'"
echo 'dns_zone_id=$(az network dns zone show --name '$dns_zone' --resource-group '$dns_rg' --query "id" --output tsv)'
echo 'echo "The DNS Zone ID is \"$dns_zone_id\""'
echo 'az role assignment create --role "Reader" --assignee $dns_sp_id --scope $dns_rg_id >/dev/null'
echo 'az role assignment create --role "Contributor" --assignee $dns_sp_id --scope $dns_zone_id >/dev/null'
echo "echo 'Role assignments for \"$dns_sp_name\" created'"

echo 'certmanager_sp_id=$(az ad sp list --display-name '$certmanager_sp_name' | jq -r ".[0].appId")'
echo 'if [ "$certmanager_sp_id" = "null" ]; then'
echo "  echo 'Creating the SP for cert-manager...'"
echo '  certmanager_sp=$(az ad sp create-for-rbac --name '$certmanager_sp_name' --years '$years')'
echo '  certmanager_sp_id=$(echo $certmanager_sp | jq -r ".appId")'
echo '  certmanager_sp_secret=$(echo $certmanager_sp | jq -r ".password")'
echo "  echo 'Service principal for certmanager created'"
echo "  echo 'Creating yaml for certmanager'"
echo '  cat <<EOF >>'$build_loc'/values.yaml
cert-manager:
  provider:
    azuredns:
      resourceGroupName: '$dns_rg'
      clientID: $certmanager_sp_id
      clientSecret: $certmanager_sp_secret
EOF'
echo 'fi'
echo 'az role assignment create --assignee $certmanager_sp_id --role "DNS Zone Contributor" --scope $dns_zone_id >/dev/null'
echo "echo 'Assigned roles to sp \"$certmanager_sp_name\"'"

echo 'kms_sp_id=$(az ad sp list --display-name '$kms_sp_name' | jq -r ".[0].appId")'
echo 'if [ "$kms_sp_id" = "null" ]; then'
echo "  echo 'Creating the SP for Azure Key Vault...'"
echo '  kms_sp=$(az ad sp create-for-rbac -n '$kms_sp_name' --years '$years')'
echo '  kms_sp_id=$(echo $kms_sp | jq -r ".appId")'
echo '  kms_sp_secret=$(echo $kms_sp | jq -r ".password")'
echo "  echo 'Service principal for Azure Key Vault created'"
echo '  cat <<EOF >>'$build_loc'/values.yaml
kms:
  azure:
    resourceGroup: '$kms_rg'
    clientId: $kms_sp_id
    clientSecret: $kms_sp_secret
EOF'
echo "fi"

ingress_ip_name=$(y sip.ingress || echo "$cluster_name-ingress")
echo "ingress_ip_id=\$(az network public-ip list --query \"[?name=='$ingress_ip_name']\".id -o tsv)"
echo 'if [ "$ingress_ip_id" = "" ]; then'
echo "  echo 'Creating static ip address for ingress with name \"$ingress_ip_name\".'"
echo "  az network public-ip create -g $aks_rg -n $ingress_ip_name --allocation-method static --sku Standard"
echo '  echo "Created static ip address for ingress"'
echo 'fi'
echo 'ingress_ip="$(az network public-ip show -g '$aks_rg' -n '$ingress_ip_name')"'
echo 'ingress_ip_id=$(echo $ingress_ip  | jq -r ".id")'
echo 'ingress_ip_addr=$(echo $ingress_ip  | jq -r ".ipAddress")'
echo 'echo "Found static ip address for ingress: name='$ingress_ip_name', ip=$ingress_ip_addr"'

egress_ip_name=$(y sip.egress || echo "$cluster_name-egress")
echo "egress_ip_id=\$(az network public-ip list --query \"[?name=='$egress_ip_name']\".id -o tsv)"
echo 'if [ "$egress_ip_id" = "" ]; then'
echo "  echo 'Creating static ip address for egress with name \"$egress_ip_name\".'"
echo "  az network public-ip create -g $aks_rg -n $egress_ip_name --allocation-method static --sku Standard"
echo '  echo "Created static ip address for egress"'
echo 'fi'
echo 'egress_ip="$(az network public-ip show -g '$aks_rg' -n '$egress_ip_name')"'
echo 'egress_ip_id=$(echo $egress_ip  | jq -r ".id")'
echo 'egress_ip_addr=$(echo $egress_ip  | jq -r ".ipAddress")'
echo 'echo "Found static ip address for egress: name='$egress_ip_name', ip=$egress_ip_addr"'

if ye appgw && ! $preview; then
  echo "echo 'Creating Application Gateway \"$appgw_name\". This will take around 10 minutes...'"
  echo "az aks network application-gateway create -n '$appgw_name' -g '$aks_rg' --zones $(y _ zones) $(y appgw.create) --public-ip-address '\$egress_ip_id'"
fi

if ye kms; then
  echo "echo 'Creating keyvault \"$kms_vault\".'"
  echo "az keyvault create --name $kms_vault --resource-group $kms_rg"
  echo "az keyvault key create --name $kms_key --vault-name $kms_vault --protection software --ops encrypt decrypt"
  echo 'kms_key_id=$(az keyvault key show --name '$kms_key' --vault-name '$kms_vault' --query key.kid)'
  echo 'az keyvault set-policy --name '$kms_vault' --resource-group '$kms_rg' --spn $kms_sp_id \
        --key-permissions encrypt decrypt'
  echo 'echo "Created key vault '$kms_vault', with key '$kms_key', with key id $kms_key_id"'
fi

echo "echo 'Creating AKS cluster \"$cluster_name\". This will take around 10 minutes...'"
echo "az aks create -n '$cluster_name' -g '$aks_rg' --generate-ssh-keys --zones $(y _ zones) --load-balancer-outbound-ips \$egress_ip_id,\$ingress_ip_id $(y aks.create) $(y aks.nodePoolDefaults)\
  $(ye acr && echo --attach-acr $(y acr name)) $(ye appgw && $preview && echo "-a ingress-appgw --appgw-name $appgw_name --appgw-subnet-cidr $(y vnet appgwSubnetCIDR)")"

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
echo 'while [ "$(az aks list -g '$aks_rg' | grep "\"name\": \"'$cluster_name'\"")" = "" ]; do echo "sleeping 5" && sleep 5; done'

# if ya aks.additionalNodePools; then
#   echo 'echo' "Adding additional node pools to AKS cluster '$cluster_name'..."
#   echo 'echo' "Coming soon!"
# fi

if ye acr; then
  echo "echo 'Attaching pull rights to Azure Container Registry \"$(y acr name)\"..."
  echo 'kubeletIdentityObjectId=$(az aks show -n '$cluster_name' -g '$aks_rg' --query identityProfile.kubeletidentity.objectId --out tsv)'
  echo 'azureContainerRegistryId=$(az acr show -n '$(y acr name)' -g '$(y acr resourceGroup)' --query id --out tsv)'
  echo 'az role assignment create --role '$(y acr role)' --assignee-object-id $kubeletIdentityObjectId --scope $azureContainerRegistryId'
fi

if ye db.postgres; then
  names=$(y db.postgres names)
  echo "echo 'Creating databases: $names'"
  for name in $names; do
    echo "az postgres server create -n '$name' -g '$aks_rg' $(y db.postgres.$name.create)"
    echo "echo 'Creating firewall rules for db \"$name\"'"
    echo "az postgres server firewall-rule create -n '$name' -g '$aks_rg' --server-name '$name' --start-ip-address \$egress_ip_addr --end-ip-address \$egress_ip_addr"
    for ip_addr in $(y db.postgres.$name ipAccess 1); do
      ip_label=$(echo $ip_addr | sed -e 's/\./-/g')
      echo "az postgres server firewall-rule create -n '$name-$ip_label' -g '$aks_rg' --server-name '$name' --start-ip-address $ip_addr --end-ip-address $ip_addr"
    done
  done
fi

echo "echo 'Done creating AKS resources for cluster \"$cluster_name\"'"
