#!/bin/bash

###############################################################################

LOCALSTACK_LAMBDA_ROLE_ARN=arn:aws:iam::000000000000:role/lambda-role

FUNCTION_NAME=kinesis-esm
FUNCTION_DIRECTORY=/lambda
FUNCTION_PACKAGE_PATH=/lambda/package.zip

PRODUCTS_EVENT_BUS_NAME=products
CUSTOMERS_EVENT_BUS_NAME=customers

###############################################################################

echo "creating lambda function..."
echo "======================================"

get_all_lambda_functions() {
    awslocal \
      lambda \
      list-functions
}

create_lambda_package() {
    local directory="$1"
    local package_file_path="$2"

    if [ ! -d "$directory" ]; then
      echo "error creating lambda package: directory '${directory}' not found."
      return 1
    fi

    echo "zipping directory '${directory}'..."
    if ! zip -r "${package_file_path}" "${directory}" -i "*.py"; then
      echo "error creating lambda package: failed to create zip file."
      return 1
    fi

    echo "lambda package created successfully: '${package_file_path}'"
}

create_lambda_function() {
    local function_name=$1
    local package_file_path=$2

    echo "deleting function '${function_name}' if it exists before recreating it with updated code..."

    awslocal \
      lambda \
      delete-function \
      --function-name $function_name \
      >/dev/null 2>&1 \
      || true

    echo "creating function '${function_name}'..."

    awslocal \
      lambda \
      create-function \
      --function-name $function_name \
      --zip-file fileb://$package_file_path \
      --runtime python3.9 \
      --handler lambda/main.handler \
      --role $LOCALSTACK_LAMBDA_ROLE_ARN \
      --environment Variables="{PRODUCTS_EVENT_BUS_NAME=$PRODUCTS_EVENT_BUS_NAME,CUSTOMERS_EVENT_BUS_NAME=$CUSTOMERS_EVENT_BUS_NAME}" \
      >/dev/null 2>&1

    echo "function '${function_name}' created successfully."
}

create_lambda_package $FUNCTION_DIRECTORY $FUNCTION_PACKAGE_PATH
create_lambda_function $FUNCTION_NAME $FUNCTION_PACKAGE_PATH

echo "functions currently exist in the localstack lambda are:"
echo "$(get_all_lambda_functions)"
