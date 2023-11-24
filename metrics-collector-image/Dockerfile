FROM registry.redhat.io/openshift4/ose-cli:v4.14

# Install the Azure CLI
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc \
  && dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm \
  && dnf install -y azure-cli

# Install jq (JSON processor)
RUN dnf -y install jq

# Copy the collector scripts and jq filters into the image
COPY ./scripts/ /opt/metrics-collector-scripts/

RUN ["chmod", "+x", "/opt/metrics-collector-scripts//collect.sh"]