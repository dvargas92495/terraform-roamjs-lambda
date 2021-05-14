terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
    github = {
      source = "integrations/github"
      version = "4.2.0"
    }
  }
}

variable "aws_access_token" {
  type = string
}

variable "aws_secret_token" {
  type = string
}

variable "developer_token" {
  type = string
}

variable "github_token" {
  type = string
}

variable "lambdas" {
  type = list(object({
    path = string
    method = string
  }))
}

variable "name" {
  type = string
}

locals {
  resources = distinct([
    for lambda in var.lambdas: lambda.path
  ])
}

# lambda resource requires either filename or s3... wow
data "archive_file" "dummy" {
  type        = "zip"
  output_path = "./dummy.zip"

  source {
    content   = "// TODO IMPLEMENT"
    filename  = "dummy.js"
  }
}

data "aws_iam_role" "roamjs_lambda_role" {
  name = "roam-js-extensions-lambda-execution"
}

data "aws_api_gateway_rest_api" "rest_api" {
  name = "roamjs-extensions"
}

resource "aws_api_gateway_resource" "resource" {
  for_each    = toset(local.resources)

  rest_api_id = data.aws_api_gateway_rest_api.rest_api.id
  parent_id   = data.aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = each.value
}

resource "aws_lambda_function" "lambda_function" {
  count    = length(var.lambdas)

  function_name = "RoamJS_${var.lambdas[count.index].path}_${lower(var.lambdas[count.index].method)}"
  role          = data.aws_iam_role.roamjs_lambda_role.arn
  handler       = "${var.lambdas[count.index].path}_${lower(var.lambdas[count.index].method)}.handler"
  filename      = data.archive_file.dummy.output_path
  runtime       = "nodejs12.x"
  publish       = false
  timeout       = 10

  tags = {
    Application = "Roam JS Extensions"
  }
}

resource "aws_api_gateway_method" "method" {
  count    = length(var.lambdas)

  rest_api_id   = data.aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.resource[var.lambdas[count.index].path].id
  http_method   = upper(var.lambdas[count.index].method)
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  count    = length(var.lambdas)

  rest_api_id             = data.aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.resource[var.lambdas[count.index].path].id
  http_method             = aws_api_gateway_method.method[count.index].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function[count.index].invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  count    = length(var.lambdas)
  
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function[count.index].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_api_gateway_rest_api.rest_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_method" "options" {
  for_each    = toset(local.resources)

  rest_api_id   = data.aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.resource[each.value].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mock" {
  for_each    = toset(local.resources)

  rest_api_id          = data.aws_api_gateway_rest_api.rest_api.id
  resource_id          = aws_api_gateway_resource.resource[each.value].id
  http_method          = aws_api_gateway_method.options[each.value].http_method
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = jsonencode(
        {
            statusCode = 200
        }
    )
  }
}

resource "aws_api_gateway_method_response" "mock" {
  for_each    = toset(local.resources)

  rest_api_id = data.aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.resource[each.value].id
  http_method = aws_api_gateway_method.options[each.value].http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true,
    "method.response.header.Access-Control-Allow-Methods"     = true,
    "method.response.header.Access-Control-Allow-Origin"      = true,
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "mock" {
  for_each    = toset(local.resources)
  rest_api_id = data.aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.resource[each.value].id
  http_method = aws_api_gateway_method.options[each.value].http_method
  status_code = aws_api_gateway_method_response.mock[each.value].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Authorization, Content-Type'",
    "method.response.header.Access-Control-Allow-Methods"     = "'GET,DELETE,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"      = "'*'",
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

resource "github_actions_secret" "deploy_aws_access_key" {
  repository       = "roamjs-${var.name}"
  secret_name      = "DEPLOY_AWS_ACCESS_KEY"
  plaintext_value  = var.aws_access_token
}

resource "github_actions_secret" "deploy_aws_access_secret" {
  repository       = "roamjs-${var.name}"
  secret_name      = "DEPLOY_AWS_ACCESS_SECRET"
  plaintext_value  = var.aws_secret_token
}

resource "github_actions_secret" "developer_token" {
  repository       = "roamjs-${var.name}"
  secret_name      = "ROAMJS_DEVELOPER_TOKEN"
  plaintext_value  = var.developer_token
}

resource "github_actions_secret" "github_token" {
  repository       = "roamjs-${var.name}"
  secret_name      = "ROAMJS_RELEASE_TOKEN"
  plaintext_value  = var.github_token
}
