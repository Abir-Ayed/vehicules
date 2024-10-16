provider "aws" {
  region = "eu-west-3"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}