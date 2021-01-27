source="${1}"
destination="${2}"
profile="${3}"

eval "arr=( $(aws ssm get-parameters-by-path --path "/version/${source}/" --profile "${profile}" | jq -r '@sh "\(.Parameters[].Name)"' ) )"

for key in "${arr[@]}"
do
  noquotes=$(echo "${key}" | sed 's/"//g')
  repo=$(echo "${noquotes}" | sed 's|.*/||')
  val=$(aws ssm get-parameter --name "${key}" --profile "${profile}" | jq ".Parameter.Value")
  aws ssm put-parameter --name "/version/${destination}/${repo}" --type "String" --value "${val}" --overwrite --profile "${profile}"
done 
