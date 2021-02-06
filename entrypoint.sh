#!/bin/bash
set -euf -o pipefail
set -x

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
copy_params staging unit-test "${INPUT_BUCKET_PREFIX}" || exit 1

if [ -n "${INPUT_PROGRAM_NAME}" ]; then
    archive_filename="${INPUT_PROGRAM_NAME}.${INPUT_EXTENSION}"
    sha=$(openssl dgst -sha256 -binary "${GITHUB_WORKSPACE}/${INPUT_BINARY_DIR}/${archive_filename}" | openssl enc -base64)
    aws s3 cp "${GITHUB_WORKSPACE}/${INPUT_BINARY_DIR}/${archive_filename}" "s3://${bucketprefix}-unit-test/build_artifacts/${archive_filename}" --metadata "sha256=${sha}"
fi

# Run tests
pushd "${GITHUB_WORKSPACE}"/"${INPUT_TEST_DIR}"
if [ -n "${INPUT_TEST_NAME}" ]; then
    go test -v -timeout 30m "${INPUT_TEST_NAME}"
else
    gotest .
fi
gotest_result=$?
popd
[ "${gotest_result}" -eq 0 ] || exit 1

# Update staging version in parameter store
copy_params unit-test staging "${INPUT_BUCKET_PREFIX}" || exit 1

# Deploy to staging
if [ -n "${INPUT_LIVE_DIR}" ]; then
    pushd "${GITHUB_WORKSPACE}"/"${INPUT_LIVE_DIR}"
    terragrunt apply-all --terragrunt-non-interactive
    terragrunt_result=$?
    popd
    [ "${terragrunt_result}" -eq 0 ] || exit 1
fi
