variable "bucket_prefix" {
    type        = string
    description = "S3 bucket prefix"
    nullable    = false
}

variable "env" {
    type        = string
    description = "Environment"
}