data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.bucket_name}"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::YOUR_ACCOUNT_ID:role/LambdaExecutionRole"]
    }
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::YOUR_ACCOUNT_ID:role/LambdaExecutionRole"]
    }
  }
}
