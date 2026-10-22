#!/bin/bash
echo "Running acceptance tests...."

if [ $# -eq 0 ]
  then
    echo "ERROR: No arguments provided."
    echo "Usage: acceptanceTest "
    echo "Usage: acceptanceTest -Dcucumber.options='--tags @pcssmoke'"
    exit 1
fi

export AWS_DEFAULT_REGION="us-east-1"
nonprod_credentials_bucket=s3://vdis-nonprod/vdis-credentials/save

crossing-go env $nonprod_credentials_bucket/config.yml > env.export

source env.export
rm ./env.export

# Get certs
crossing-go get $nonprod_credentials_bucket/keystore.jks keystore/keystore.jks
crossing-go get $nonprod_credentials_bucket/elis-keystore.jks keystore/elis-keystore.jks
crossing-go get $nonprod_credentials_bucket/elis-cert.cer keystore/elis-cert.cer

set -x

#Run acceptance test
if [ "$#" -eq  "2" ]
  then
     eval "./gradlew $1 -Dcucumber.options='--tags $2'"
 else
     eval "./gradlew $1"
fi
