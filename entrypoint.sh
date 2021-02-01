#!/bin/bash

copy_params() {
    source="${1}"
    destination="${2}"
    profile="${3}"

    eval "arr=( $(aws ssm get-parameters-by-path --path "/version/${source}/" | jq -r '@sh "\(.Parameters[].Name)"' ) )"

    for key in "${arr[@]}"
    do
        noquotes=$(echo "${key}" | sed 's/"//g')
        repo=$(echo "${noquotes}" | sed 's|.*/||')
        val=$(aws ssm get-parameter --name "${key}" | jq ".Parameter.Value")
        valnoquotes=$(echo "${val}" | sed 's/"//g')
        aws ssm put-parameter --name "/version/${destination}/${repo}" --type "String" --value "${valnoquotes}" --overwrite
    done
}

function gotest(){
    find $1 -name '*.go' | xargs -n1 -P1 go test -v -timeout 30m
}

# Update unit-test version in parameter store
aws configure set aws_access_key_id "${INPUT_AWS_ACCESS_KEY_ID}" || exit 1
aws configure set aws_secret_access_key "${INPUT_AWS_SECRET_ACCESS_KEY}" || exit 1
aws configure set region "${INPUT_AWS_REGION}" || exit 1
copy_params staging unit-test ssm-param || exit 1

if [ -n "${INPUT_PROGRAM_NAME}" ]; then
    aws ssm put-parameter --name "/version/unit-test/${INPUT_PROGRAM_NAME}" --type "String" --value "${INPUT_NEW_TAG}" --overwrite || exit 1
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
copy_params unit-test staging ssm-param || exit 1

# Deploy to staging
if [ -n "${INPUT_LIVE_DIR}" ]; then
    pushd "${GITHUB_WORKSPACE}"/"${INPUT_LIVE_DIR}"
    terragrunt apply-all --terragrunt-non-interactive
    terragrunt_result=$?
    popd
    [ "${terragrunt_result}" -eq 0 ] || exit 1
fi
