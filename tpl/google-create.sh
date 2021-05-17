#!/usr/bin/env bash
echo '#!/usr/bin/env bash'

org_id=$(y _ organizationId)
project=$(y _ project)
region=$(y _ region)
location=$(y bq location)
metering_set=$(y bq metering-set)
dns_zone=$(y dns zone)
dns_name=$(y dns name)
dns_manager=$(y dns accountName || echo 'dnsmanager')
dns_manager_sa_email="serviceAccount:$dns_manager@$project.iam.gserviceaccount.com"
cluster_name="otomi-gke-$CLUSTER"

echo "if ! bq --project_id '$project' --location '$location' ls '$metering_set' >/dev/null; then"
# create a metering table that will store records for 10 years
echo "  bq --project_id '$project' --location '$location' mk -d --default_table_expiration 315360000 --description 'Contains billing records based on labels.' $metering_set"
echo 'fi'

echo "if ! gcloud dns --project '$project' managed-zones describe '$dns_zone' >/dev/null; then"
#create the dns zone
echo "  gcloud dns --project '$project' managed-zones create '$dns_zone' --description= --dns-name '$dns_name'"
echo "  echo 'Get the domain servers from the $zone_zone dns zone by clicking here:'"
echo "  echo 'https://console.cloud.google.com/net-services/dns/zones/$dns_zone/?project=$project&authuser=1&organizationId=$org_id&orgonly=true'"
echo "  echo 'and make sure the domain registrar uses them, then continue here'"
echo "  echo -n 'Ready to proceed (y/n)? '"
echo "  read answer"
echo '  [ "$answer" != "${answer#[Yy]}" ] && exit'
echo 'fi'

echo "if ! gcloud iam service-accounts list | grep -e '^$dns_manager' >/dev/null; then"
# set up otomi-dns-manager service account
echo "  gcloud iam service-accounts create '$dns_manager' --display-name '$dns_manager' --project '$project'"
echo "  gcloud iam service-accounts keys create '$build_loc/$dns_manager.json' --iam-account='$dns_manager_sa_email'"
echo "  gcloud projects add-iam-policy-binding '$project' --member '$dns_manager_sa_email' --role 'roles/dns.admin'"
echo 'fi'

# create the cluster
echo "gcloud container clusters create '$cluster_name' \
--project '$project' \
$(y gke) \
--network 'projects/$project/global/networks/default' \
--no-enable-basic-auth \
--no-enable-stackdriver-kubernetes \
--region '$region' \
--resource-usage-bigquery-dataset $metering_set \
--scopes https://www.googleapis.com/auth/cloud-platform \
--subnetwork 'projects/$project/regions/$region/subnetworks/default'"

echo "gcloud container clusters get-credentials '$cluster_name' --region '$region' --project '$project'"

echo 'kubectl create clusterrolebinding cluster-admin-binding --clusterrole="cluster-admin" --user "$(gcloud config get-value account)"'
