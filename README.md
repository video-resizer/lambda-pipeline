# lambda-pipeline
A deployment pipeline for AWS Lambda functions

## Description

Given the name of an archive file (PROGRAM\_NAME) and the name of a directory containing integration tests (TEST\_DIR), this action uploads the archive file to an S3 bucket having a name consisting of BUCKET\_PREFIX and "-unit-test", and executes the test(s). Upon success, it copies the archive file from the original bucket to a bucket having a name consisting of BUCKET\_PREFIX and "-staging". If the optional LIVE\_DIR argument is passed, the action will execute the terragrunt apply-all command against the contents of LIVE\_DIR.

If PROGRAM\_NAME is empty, no archive file is uploaded to S3, but tests are still run.

## Usage

```
- name: Pipeline
  uses: thekguy/lambda-pipeline@main
  with:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_REGION: ${{ secrets.AWS_REGION }}
    BUCKET_PREFIX: my-unique-bucket-prefix
    PROGRAM_NAME: myprogram
    TEST_DIR: test
    TEST_NAME: mytest.go
```

### Variables

| Name                    | Required | Default             |
|-------------------------|----------|---------------------|
| `AWS_ACCESS_KEY_ID`     | true     |                     |
| `AWS_SECRET_ACCESS_KEY` | true     |                     |
| `AWS_REGION`            | true     |                     |
| `BUCKET_PREFIX`         | true     |                     |
| `PROGRAM_NAME`          | false    |                     |
| `EXTENSION`             | false    | zip                 |
| `BINARY_DIR`            | false    | deployment\_package |
| `TEST_DIR`              | false    | modules/test        |
| `TEST_NAME`             | false    |                     |
| `LIVE_DIR`              | false    | modules/live        |
