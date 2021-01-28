AWS_ACCESS_KEY_ID="${1}"
AWS_SECRET_ACCESS_KEY="${2}"
AWS_REGION="${3}"
PROGRAM_NAME="${4}"
NEW_TAG="${5}"
TEST_DIR="${6}"
TEST_NAME="${7}"

# Update unit-test version in parameter store
aws configure --profile ssm-param set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
aws configure --profile ssm-param set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
aws configure --profile ssm-param set region "${AWS_REGION}"
./copy-params.sh staging unit-test ssm-param
aws ssm put-parameter --name "/version/unit-test/${PROGRAM_NAME}" --type "String" --value "${NEW_TAG}" --overwrite --profile ssm-param

# Run tests
pushd "${TEST_DIR}"
go test -count=1 -v -timeout 30m "${TEST_NAME}"
popd
# Update staging version in parameter store
./copy-params.sh unit-test staging ssm-param
