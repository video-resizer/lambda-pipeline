#!/bin/bash
set -euf -o pipefail

copy_params() {
    local source="${1}"
    local destination="${2}"
    local bucketprefix="${3}"

    eval "arr=( $(aws s3api list-objects --bucket "${bucketprefix}-${source}" --query 'Contents[].Key' | jq -r '[.[] | select(endswith(".zip") or endswith(".jar"))] | @sh' ) )"
    if [ "${#arr[@]}" -eq "0" ]; then
      echo "s3 list-objects returned zero objects for bucket ${bucketprefix}-${source}. Quitting."
      return 1
    fi

    for key in "${arr[@]}"
    do
        local sourceval=$(aws s3api head-object --bucket "${bucketprefix}-${source}" --key "${key}" | jq .Metadata.sha256)
        if [ "${#sourceval}" -eq "0" ]; then
          echo "s3api head-object could not get a sha256 for object ${key} in bucket ${bucketprefix}-${source}. Quitting."
          return 1
        fi

        local destinationval=$(aws s3api head-object --bucket "${bucketprefix}-${destination}" --key "${key}" | jq .Metadata.sha256)
        if [ "${#destinationval}" -eq "0" ]; then
          echo "s3api head-object could not get a sha256 for object ${key} in bucket ${bucketprefix}-${destination}. Quitting."
          return 1
        fi

        if [ "${sourceval}" != "${destinationval}" ]; then
            local sourcevalnoquotes=$(echo "${sourceval}" | sed 's/"//g')
            aws s3 cp "s3://${bucketprefix}-${source}/${key}" "s3://${bucketprefix}-${destination}/${key}" --metadata "sha256=${sourceval}" --acl bucket-owner-full-control || return 1
        fi
    done
}

function gotest(){
    find $1 -name '*.go' | xargs -n1 -P1 go test -v -timeout 30m
}

function use_input_credentials() {
    local key_id="${1}"
    local secret="${2}"
    aws configure set aws_access_key_id "${key_id}" || return 1
    aws configure set aws_secret_access_key "${secret}" || return 1
    aws configure set aws_session_token "" || return 1
}

function assume_role() {
    local role_to_assume="${1}"
    if [ -n "${role_to_assume}" ]; then
        role_json=$(aws sts assume-role --role-arn "${role_to_assume}" --role-session-name "assume-role-to-read-bucket")
        AK_ID=$(echo "${role_json}" | jq -r .Credentials.AccessKeyId)
        aws configure set aws_access_key_id "${AK_ID}" || return 1
        SEC_AK=$(echo "${role_json}" | jq -r .Credentials.SecretAccessKey)
        aws configure set aws_secret_access_key "${SEC_AK}" || return 1
        SESS=$(echo "${role_json}" | jq -r .Credentials.SessionToken)
        aws configure set aws_session_token "${SESS}" || return 1
    fi
}

aws configure set region "${INPUT_AWS_REGION}" || exit 1

use_input_credentials "${INPUT_AWS_ACCESS_KEY_ID}" "${INPUT_AWS_SECRET_ACCESS_KEY}" || exit 1

assume_role "${INPUT_ASSUME_ROLE}" || exit 1

copy_params staging unit-test "${INPUT_BUCKET_PREFIX}" || exit 1

if [ -n "${INPUT_PROGRAM_NAME}" ]; then
    archive_filename="${INPUT_PROGRAM_NAME}.${INPUT_EXTENSION}"
    sha=$(openssl dgst -sha256 -binary "${GITHUB_WORKSPACE}/${INPUT_BINARY_DIR}/${archive_filename}" | openssl enc -base64)
    if [ "${#sha}" -eq "0" ]; then
      echo "Computed an empty sha256 for ${GITHUB_WORKSPACE}/${INPUT_BINARY_DIR}/${archive_filename}. Quitting."
      exit 1
    fi
    aws s3 cp "${GITHUB_WORKSPACE}/${INPUT_BINARY_DIR}/${archive_filename}" "s3://${INPUT_BUCKET_PREFIX}-unit-test/build_artifacts/${archive_filename}" --metadata "sha256=${sha}" --acl bucket-owner-full-control || exit 1
fi

use_input_credentials "${INPUT_AWS_ACCESS_KEY_ID}" "${INPUT_AWS_SECRET_ACCESS_KEY}" || exit 1

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

# Clean up unit-test environment
if [ -n "${INPUT_CLEANUP_SCRIPT}" ]; then
    source "${INPUT_CLEANUP_SCRIPT}" "${GITHUB_WORKSPACE}"/"${INPUT_TEST_DIR}"/..
fi

assume_role "${INPUT_ASSUME_ROLE}" || exit 1

# Update staging version in parameter store
copy_params unit-test staging "${INPUT_BUCKET_PREFIX}" || exit 1

use_input_credentials "${INPUT_AWS_ACCESS_KEY_ID}" "${INPUT_AWS_SECRET_ACCESS_KEY}" || exit 1

# Deploy to staging
if [ -n "${INPUT_LIVE_DIR}" ] && [[ "${INPUT_BRANCH}" = "develop" ]]; then
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

    # Clean up staging environment
    if [ -n "${INPUT_CLEANUP_SCRIPT}" ]; then
        source "${INPUT_CLEANUP_SCRIPT}" "${GITHUB_WORKSPACE}"/"${INPUT_LIVE_DIR}"/..
    fi
fi
