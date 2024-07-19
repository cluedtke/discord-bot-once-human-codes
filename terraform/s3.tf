resource "aws_s3_bucket" "once_human_codes" {
  bucket = local.app_name
}

resource "aws_s3_object" "once_human_codes_object" {
  bucket = aws_s3_bucket.once_human_codes.bucket
  key    = "codes.txt"
}
