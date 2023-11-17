## Build the Metrics Collector Image

This shows how to build the image using an OpenShift build. The image could also be built in a pipeline and the resulting image pushed to an accessible container registry.

1. Make sure that you can pull from the RH container registry, for example:
    ```
    oc create secret generic rh-reg --from-file=.dockerconfigjson=<auth_json> --type=kubernetes.io/dockerconfigjson

    oc secrets link builder rh-reg
    ```

1. Create a new OpenShift build:
    ```
    oc new-build https://github.com/adamclark/metrics-collector.git#main --context-dir=metrics-collector-image --allow-missing-images
    ```

## Deploy the Metrics Collector CronJob

1. Create a secret with the Azure blob store credentials. This secret should be in the form:

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
        name: metrics-collector-azure-blob-store
    type: Opaque
    stringData:
        storage_account: <storage_acct>
        storage_container: <container_name>
        sas_token: <token>
    ```

1. To deploy the CronJob run:
    ```
    helm template mycollector metrics-collector-deploy | oc apply -f -
    ```