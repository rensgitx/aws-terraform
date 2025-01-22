resource "aws_s3_bucket" "sketchpad" {

    bucket     = "${var.bucket_prefix}-sketchpad"
    acl        = "private"

    tags = {
        Name        = "${var.bucket_prefix}-sketchpad"
        ManagedBy   = "terraform"
        Environment = "${var.env}"
    } 
}