variable "bucket_name" {
  type = string
  description = "Name of the S3 bucket"
  default= "vehicules"
}

variable "environment" {
  type    = string
  default = "dev"
  
}