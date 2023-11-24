#!/bin/bash

WORKING_DIR=/tmp
export AZURE_CONFIG_DIR="${WORKING_DIR}/.azure"

cd ${WORKING_DIR}


# This is the date format required, including hours/mins while testing at increased frequency
# DATE=$(date "+%Y-%m-%d")
DATE=$(date "+%Y-%m-%d-%H-%M")
echo $DATE
CLUSTER=$(oc get clusterversion -o jsonpath='{.items[].spec.clusterID}{"\n"}')
echo $CLUSTER
DATE_CLUSTER=${DATE}_${CLUSTER}
echo $DATE_CLUSTER


# --- STEP 1 - COLLECT DATA FROM OPENSHIFT

# Extract the data from the OpenShift cluster
oc get namespace --output=json > ${DATE_CLUSTER}_namespace.json
oc get quota -A -o json > ${DATE_CLUSTER}_quota.json
oc get pvc -A -o json > ${DATE_CLUSTER}_pvc.json
oc version -o json > ${DATE_CLUSTER}_version.json
oc get pods -A --output=json > ${DATE_CLUSTER}_pod.json

# Convert the data to the required CSV format
FILTERS_DIR=/opt/metrics-collector-scripts
jq -rf ${FILTERS_DIR}/namespace-filter.jq ${DATE_CLUSTER}_namespace.json > ${DATE_CLUSTER}_namespace.csv
jq -rf ${FILTERS_DIR}/quota-filter.jq ${DATE_CLUSTER}_quota.json > ${DATE_CLUSTER}_quota.csv
jq -rf ${FILTERS_DIR}/pvc-filter.jq ${DATE_CLUSTER}_pvc.json > ${DATE_CLUSTER}_pvc.csv
jq -rf ${FILTERS_DIR}/version-filter.jq ${DATE_CLUSTER}_version.json > ${DATE_CLUSTER}_version.csv
jq -rf ${FILTERS_DIR}/pod-filter.jq ${DATE_CLUSTER}_pod.json > ${DATE_CLUSTER}_pod.csv


# --- STEP 2 - COLLECT DATA FROM AZURE

containerData=()

# Loop to go over each container and calculate size
while IFS= read -r container; do
    listOfBlobs=$(az storage blob list --account-name $STORAGE_ACCOUNT --sas-token $STORAGE_ACCOUNT_READ_SAS_TOKEN --container-name $container --query '[].properties.contentLength' -o tsv)
    containerLength=0

    # Calculate the size of blobs in the current container
    for blob in $listOfBlobs; do
        containerLength=$((containerLength + blob))
    done
    
    ContainerSizeKB=$(echo "scale=2; $containerLength / 1024" | bc -l)
    
    # Add the container data to the array
    containerData+=("ContainerName=$container" "ContainerSizeKB=$ContainerSizeKB")
done < <(az storage container list --account-name $STORAGE_ACCOUNT --sas-token $STORAGE_ACCOUNT_READ_SAS_TOKEN --query '[].name' -o tsv)

# Export the container data to a CSV file
printf "%s\n" "${containerData[@]}" | paste -d ',' - - > "${DATE_CLUSTER}_storage.csv"


# --- STEP 2 - UPLOAD DATA TO AZURE BLOB STORE

for f in ${DATE_CLUSTER}_*.csv
do
  curl -X PUT -T ./${f} -H "x-ms-date: $(date -u)" -H "x-ms-blob-type: BlockBlob" "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${STORAGE_CONTAINER}/${f}?${CONTAINER_UPLOAD_SAS_TOKEN}"
done