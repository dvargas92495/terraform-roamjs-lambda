# roamjs-lambda

Creates the API backend infrastructure for RoamJS extensions. The module is very opinionated and will not work for any use case outside of RoamJS.

## Features

- Adds lambdas to the https://lambdas.roamjs.com API Gateway
- Adds GitHub secrets to the extension's repositories

## Usage

```hcl
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

provider "aws" {
    region = "us-east-1"
    access_key = var.aws_access_token
    secret_key = var.aws_secret_token
}

provider "github" {
    owner = "dvargas92495"
    token = var.github_token
}

module "roamjs_lambda" {
  source    = "dvargas92495/lambda/roamjs"

  name = "example"
  lambdas = [
    { 
      path = "resource", 
      method = "get"
    },
    {
      path = "another_resource",
      method = "post"
    }
  ]
  aws_access_token = var.aws_access_token
  aws_secret_token = var.aws_secret_token
  github_token     = var.github_token
  developer_token  = var.developer_token
}
```

## Inputs
- `aws_access_token` - The AWS Access Token to access RoamJS.
- `aws_secret_token` - The AWS Secret Token to access RoamJS.
- `github_token` - The github token to access your extension's repository.
- `developer_token` - The developer token to access your extension's path.
- `lambdas`

## Output

There are no exposed outputs
