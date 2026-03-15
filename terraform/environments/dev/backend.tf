terraform {
  backend "s3" {
    bucket = "devopsexpert-shared"
    key    = "devopsexpert-shared/environments/dev/terraform.tfstate"
    region = "ap-south-1"

    use_lockfile = true
    encrypt      = true
  }
}
