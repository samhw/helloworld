#!/bin/bash

echo "==========================================================="
echo "VDIS SAVE Microservice entrypoint.sh starting up with PID $$"
echo "==========================================================="

set -euo pipefail

lowered_cluster_env=`echo $TARGET_AWS_ACCOUNT | tr '[:upper:]' '[:lower:]'`
lowered_deploy_name=`echo $TARGET_DEPLOY_ENV | tr '[:upper:]' '[:lower:]'`
# extended flow defines newrelic name in inputset as NEW_RELIC_APP_NAME
kafka_newrelic_app_name=$NEW_RELIC_APP_NAME

echo "Cluster Env: $lowered_cluster_env"
echo "Deploy: $lowered_deploy_name"

swaggerUrl=''
case $lowered_deploy_name in
  devtest)
    swaggerUrl='uscis-dev.api-nonprod.uscis.dhs.gov/vdis/save/devtest'
    ;;

  systest)
    swaggerUrl='uscis-dev.api-nonprod.uscis.dhs.gov/vdis/save/systest'
    ;;

  externaltest)
    swaggerUrl='uscis-int.api.uscis.dhs.gov/vdis/save/externaltest'
    ;;

  preview)
    swaggerUrl='uscis-int.api.uscis.dhs.gov/vdis/save/preview'
    ;;

  prod)
    swaggerUrl='uscis-prod.api.uscis.dhs.gov/vdis/save'
    ;;

esac

echo "Apigee Swagger url: $swaggerUrl"

export version="$PIPELINE_INSTANCE_ID"
export environment="$lowered_cluster_env $lowered_deploy_name"
export swaggerHostUrl="$swaggerUrl"

export AWS_REGION=us-east-1

kafka_prefix=""
if [[ "$lowered_cluster_env" == "prod" ]]; then
    case $lowered_deploy_name in
        prod)
            kafka_prefix=""
            ;;
        preview|externaltest)
            kafka_prefix="preview-"
            ;;
        *)
            ;;
    esac
fi

crossing-go get s3://vdis-$lowered_cluster_env/vdis-credentials/save/keystore.jks ./keystore/keystore.jks 2>&1
crossing-go env s3://vdis-$lowered_cluster_env/vdis-credentials/save/config.yml >  ./docker.env.export
crossing-go get s3://vdis-$lowered_cluster_env/vdis-credentials/save/elis-keystore.jks ./keystore/elis-keystore.jks 2>&1
crossing-go get s3://vdis-$lowered_cluster_env/vdis-credentials/save/elis-cert.cer ./keystore/elis-cert.cer 2>&1
crossing-go get s3://vdis-$lowered_cluster_env/vdis-credentials/save/uscis-ca-chain.pem ./keystore/uscis-ca-chain.pem 2>&1
crossing-go get s3://vdis-$lowered_cluster_env/vdis-credentials/save/adis-ca-chain.pem ./keystore/adis-ca-chain.pem 2>&1

crossing-go get s3://vdis-$lowered_cluster_env/vdis-credentials/save/${kafka_prefix}kafka-keystore.jks ./keystore/kafka-keystore.jks 2>&1

echo "After crossing-go steps"

#looking at environments other than prod, nonprod to get environment variables
if [ $lowered_cluster_env == 'prod' ]; then
    s3file="s3://vdis-$lowered_cluster_env/vdis-credentials/save/$lowered_deploy_name-config.yml"
    if lowered_env_config=$(crossing-go env $s3file) ; then
        echo "$lowered_env_config" >> ./docker.env.export
    else
        echo "Unable to retrieve $s3file"
    fi
fi

echo "After scanning for env-config.yml"

source docker.env.export

if [ "$lowered_cluster_env" = "prod" ]
then
    export PROFILE_TOGGLES="${prod_PROFILE_TOGGLES}${ADDITIONAL_PROFILE_TOGGLES:+,${ADDITIONAL_PROFILE_TOGGLES}}"
else
    TEMP_TOGGLES="${lowered_deploy_name}_PROFILE_TOGGLES"
    export PROFILE_TOGGLES="${!TEMP_TOGGLES}${ADDITIONAL_PROFILE_TOGGLES:+,${ADDITIONAL_PROFILE_TOGGLES}}"
fi

if [ "$lowered_deploy_name" != "prod" ]
then
    export SPRING_TABLE_SUFFIX="_${lowered_deploy_name}"
    TEMP_SERVLET_CONTEXT="${SWAGGER_SERVLET_CONTEXT}/$lowered_deploy_name"
    export SWAGGER_SERVLET_CONTEXT=${TEMP_SERVLET_CONTEXT}
fi

echo "Before NR step"

if [[ "$PROFILE_TOGGLES" == *"kafka-enabled"* ]]; then
  export SPRING_THREADS_VIRTUAL_ENABLED=true # Note: using virtual threads for kafka implementation - remove if revert is needed!
  NEW_RELIC_APP_NAME=$kafka_newrelic_app_name
  if [[ "$lowered_deploy_name" == "devtest" ]]; then # devtest has ssl and encryption disabled
    export KAFKA_ENCRYPTION_ENABLED=false
  else
    export PROFILE_TOGGLES="$PROFILE_TOGGLES,kafka-ssl"
  fi
else
  NEW_RELIC_APP_NAME="$NEW_RELIC_APP_NAME-$lowered_deploy_name ($lowered_cluster_env)"
fi

echo "Before Java app step"

java -XX:MaxRAMPercentage=75 \
 -Djava.security.egd=file:/dev/./urandom \
 -Dnewrelic.config.host=gov-collector.newrelic.com \
 -Dnewrelic.environment=$TARGET_DEPLOY_ENV \
 -Dnewrelic.config.file=/app/newrelic.yml \
 -javaagent:/opt/newrelic/newrelic.jar \
 --add-opens java.base/java.lang=ALL-UNNAMED \
 -jar -Dspring.profiles.active=$PROFILE /app/app.jar

echo "After Java app step"