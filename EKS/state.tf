terraform {
  backend "s3" {
    bucket       = "my-27-state-bucket"
    key          = "eksv1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true #S3 native locking
  }
}
