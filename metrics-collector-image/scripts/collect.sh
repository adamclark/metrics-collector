#!/bin/bash

WORKING_DIR=/tmp

cd ${WORKING_DIR}

# This is the date format required, including hours/mins while testing at increased frequency
# DATE=$(date "+%Y-%m-%d")
DATE=$(date "+%Y-%m-%d-%H-%M")
echo $DATE
CLUSTER=$(oc get clusterversion -o jsonpath='{.items[].spec.clusterID}{"\n"}')
echo $CLUSTER
DATE_CLUSTER=${DATE}_${CLUSTER}
echo $DATE_CLUSTER

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

# Upload the CSV files to Azure blob storage
for f in ${DATE_CLUSTER}_*.csv
do
  echo curl -X PUT -T ./${f} -H \"x-ms-date: $(date -u)\" -H \"x-ms-blob-type: BlockBlob\" \"https://${STORAGE_ACCOUNT}.blob.core.windows.net/${STORAGE_CONTAINER}/${f}?${SAS_TOKEN}\"
  curl -X PUT -T ./${f} -H "x-ms-date: $(date -u)" -H "x-ms-blob-type: BlockBlob" "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${STORAGE_CONTAINER}/${f}?${SAS_TOKEN}"
done

echo "Finished"
