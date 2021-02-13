#!/bin/bash
set -euf -o pipefail

copy_params() {
    source="${1}"
    destination="${2}"
    bucketprefix="${3}"

    eval "arr=( $(aws s3api list-objects --bucket "${bucketprefix}-${source}" --query 'Contents[].Key' | jq -r '[.[] | select(endswith(".zip") or endswith(".jar"))] | @sh' ) )"
    for key in "${arr[@]}"
    do
        sourceval=$(aws s3api head-object --bucket "${bucketprefix}-${source}" --key "${key}" | jq .Metadata.sha256)
        destinationval=$(aws s3api head-object --bucket "${bucketprefix}-${destination}" --key "${key}" | jq .Metadata.sha256)
        if [ "${sourceval}" != "${destinationval}" ]; then
            sourcevalnoquotes=$(echo "${sourceval}" | sed 's/"//g')
            aws s3 cp "s3://${bucketprefix}-${source}/${key}" "s3://${bucketprefix}-${destination}/${key}" --metadata "sha256=${sourceval}"
        fi
    done
}

function gotest(){
    find $1 -name '*.go' | xargs -n1 -P1 go test -v -timeout 30m
}

aws configure set aws_access_key_id "${INPUT_AWS_ACCESS_KEY_ID}" || exit 1
aws configure set aws_secret_access_key "${INPUT_AWS_SECRET_ACCESS_KEY}" || exit 1
aws configure set region "${INPUT_AWS_REGION}" || exit 1

if [ -n "${INPUT_ASSUME_ROLE}" ]; then
    role_json=$(aws sts assume-role --role-arn "${INPUT_ASSUME_ROLE}" --role-session-name "assume-role-to-read-bucket")
    AK_ID=$(echo "${role_json}" | jq -r .Credentials.AccessKeyId)
    aws configure set aws_access_key_id "${AK_ID}" || exit 1
    SEC_AK=$(echo "${role_json}" | jq -r .Credentials.SecretAccessKey)
    aws configure set aws_secret_access_key "${SEC_AK}" || exit 1
    SESS=$(echo "${role_json}" | jq -r .Credentials.SessionToken)
    aws configure set aws_session_token "${SESS}" || exit 1
fi

copy_params staging unit-test "${INPUT_BUCKET_PREFIX}" || exit 1

if [ -n "${INPUT_PROGRAM_NAME}" ]; then
    archive_filename="${INPUT_PROGRAM_NAME}.${INPUT_EXTENSION}"
    sha=$(openssl dgst -sha256 -binary "${GITHUB_WORKSPACE}/${INPUT_BINARY_DIR}/${archive_filename}" | openssl enc -base64)
    aws s3 cp "${GITHUB_WORKSPACE}/${INPUT_BINARY_DIR}/${archive_filename}" "s3://${bucketprefix}-unit-test/build_artifacts/${archive_filename}" --metadata "sha256=${sha}"
fi

# Run tests
#pushd "${GITHUB_WORKSPACE}"/"${INPUT_TEST_DIR}"
#if [ -n "${INPUT_TEST_NAME}" ]; then
#    go test -v -timeout 30m "${INPUT_TEST_NAME}"
#else
#    gotest .
#fi
#gotest_result=$?
#popd
#[ "${gotest_result}" -eq 0 ] || exit 1

# Update staging version in parameter store
copy_params unit-test staging "${INPUT_BUCKET_PREFIX}" || exit 1

aws configure set aws_access_key_id "${INPUT_AWS_ACCESS_KEY_ID}" || exit 1
aws configure set aws_secret_access_key "${INPUT_AWS_SECRET_ACCESS_KEY}" || exit 1
aws configure set aws_session_token "" || exit 1

# Deploy to staging
if [ -n "${INPUT_LIVE_DIR}" ]; then
    comp_array=($INPUT_COMPONENTS)
    for key in "${comp_array[@]}"
    do
        pushd "${GITHUB_WORKSPACE}"/"${INPUT_LIVE_DIR}/${key}"
        terraform init
        terraform apply -auto-approve
        terraform_result=$?
        popd
    done
    [ "${terraform_result}" -eq 0 ] || exit 1
fi
