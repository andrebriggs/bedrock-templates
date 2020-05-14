    set -e

    echo "az login --service-principal --username $SP_APP_ID --tenant ${{ parameters.tenantId }}"
    az login --service-principal --username "$SP_APP_ID" --password "$SP_PASS" --tenant "$SP_TENANT"