storage_account_id=$(az storage account show -n $storage_account_name -g $storage_rg --query id -o tsv) 2>/dev/null
if [ -z "$storage_account_id" ]; then
    storage_account_id=$(az storage account create -n $storage_account_name -g $storage_rg $storage_params --default-action Deny --bypass AzureServices $subnet --query id -o tsv)
    export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $storage_account_name -g $storage_rg -o tsv)
    storage_key=$(az storage account keys list --resource-group $storage_rg --account-name $storage_account_name --query '[0].value' -o tsv)
    echo 'Creating yaml for storage'

    cat <<-EOF >>$build_loc_rel/values.yaml
	storage-'$storage_account_name':
	resourceGroup: '$storage_rg'
	accountName: '$storage_account_name'
	accountKey: '$storage_key'
	EOF
fi
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $storage_account_name -g $storage_rg -o tsv)
az role assignment create --role "Storage Blob Data Contributor" --assignee '$user_id' --scope '$storage_account_id' --only-show-errors --query id -o tsv
echo "Assigned role 'Storage Blob Data Contributor' to SP '$user_id' on scope '$storage_account_id'."
