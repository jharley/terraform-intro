provider "aws" {
  region  = "us-east-2"
  version = "~> 2.12"
}

provider "cloudflare" {
  version = "~> 1.15"
}

provider "random" {
  version = "~> 2.1"
}
