# lambda-pipeline
A deployment pipeline for AWS Lambda functions

## Description

Given a program name, git tag, and directory containing integration tests, this action promotes via parameter store tag updates and tests the program as a Lambda. It assumes that your test program creates/updates the Lambda as part of its execution and, in the process, looks up an AWS SSM parameter located under 'phase/PROGRAM_NAME/version' to compute the name of the Lambda's zip file, where phase is currently limited to 'unit-test' and 'staging'.

## Usage

```
- name: Pipeline
  uses: thekguy/lambda-pipeline@main
  with:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_REGION: ${{ secrets.AWS_REGION }}
    PROGRAM_NAME: myprogram
    NEW_TAG: ${{ steps.version.outputs.new_tag }} # if using anothrNick/github-tag-action
    TEST_DIR: test
    TEST_NAME: mytest.go
```

### Variables

| Name                    | Required | Default |
|-------------------------|----------|---------|
| `AWS_ACCESS_KEY_ID`     | true     |         |
| `AWS_SECRET_ACCESS_KEY` | true     |         |
| `AWS_REGION`            | true     |         |
| `PROGRAM_NAME`          | true     |         |
| `NEW_TAG`               | true     |         |
| `TEST_DIR`              | true     |         |
| `TEST_NAME`             | false    |         |
