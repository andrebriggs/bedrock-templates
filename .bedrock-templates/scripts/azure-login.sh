    set -e

    echo "az login --service-principal --username $SP_APP_ID --tenant $SP_TENANT"
    az login --service-principal --username "$SP_APP_ID" --password "$SP_PASS" --tenant "$SP_TENANT"