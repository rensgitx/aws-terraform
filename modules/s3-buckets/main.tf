data "aws_caller_identity" "current" {}

/* apps bucket */
resource "aws_s3_bucket" "apps" {

  bucket     = "${var.bucket_prefix}-${var.env}-apps"
  acl        = "private"

  tags = {
    Name        = "${var.bucket_prefix}-${var.env}-apps"
  } 
}

output "apps_bucket_name" {
  value = aws_s3_bucket.apps.id
}

# tfstate bucket
resource "aws_s3_bucket" "tfstate" {
  /* 
  To create the backend bucket
  For referring to the tfstate bucket, load the backend module
  For example, see envs/dev/backend.tf
  */

  bucket     = "${var.bucket_prefix}-${var.env}-tfstate"
  acl        = "private"

  versioning {
      enabled = true
  }

  tags = {
    Name        = "${var.bucket_prefix}-${var.env}-tfstate"
  } 
}

# tfstate S3 bucket policy 
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.tfstate.arn}",
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
      }
    ]
  })
}
