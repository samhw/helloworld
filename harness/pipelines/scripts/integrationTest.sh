#!/bin/bash
echo "Running integration tests...."

export AWS_DEFAULT_REGION="us-east-1"

credentials_bucket=s3://vdis-nonprod/vdis-credentials/save
crossing-go env $credentials_bucket/config.yml > env.export
source env.export
rm ./env.export

# Get certs
crossing-go get $credentials_bucket/keystore.jks keystore/keystore.jks
crossing-go get $credentials_bucket/elis-keystore.jks keystore/elis-keystore.jks
crossing-go get $credentials_bucket/elis-cert.cer keystore/elis-cert.cer

#Run integration tests
eval "./gradlew $1"
