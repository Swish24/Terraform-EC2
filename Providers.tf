provider "aws" {
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "dj-cli"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "Development"
      Owner       = "DJ"
    }
  }
}