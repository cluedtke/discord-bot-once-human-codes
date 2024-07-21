# Lambda CI
resource "null_resource" "ci_build" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command     = <<EOT
      rm -rf ci
      mkdir ci
      cp lambda.py ci/lambda_function.py
      pip install -r requirements.txt -t ci/
    EOT
    working_dir = "${path.module}/../"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../ci"
  output_path = "lambda_function.zip"
  depends_on  = [null_resource.ci_build]
}

# Lambda Resource
resource "aws_lambda_function" "lambda" {
  function_name    = local.app_name
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  timeout          = 10
  memory_size      = 128
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DISCORD_WEBHOOK = sensitive(var.discord_webhook)
      S3_BUCKET       = aws_s3_bucket.once_human_codes.bucket
      S3_KEY          = aws_s3_object.once_human_codes_object.key
    }
  }

  tracing_config {
    mode = "PassThrough"
  }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "logs" {
  name = "/aws/lambda/${aws_lambda_function.lambda.function_name}"

  retention_in_days = 30
}

# Lambda Trigger
resource "aws_cloudwatch_event_rule" "cron_schedule" {
  name        = "${local.app_name}-schedule"
  description = "Schedule for Discord Bot"

  schedule_expression = "cron(0 14 * * ? *)" #8am CST
}

resource "aws_cloudwatch_event_target" "cron_target" {
  rule      = aws_cloudwatch_event_rule.cron_schedule.name
  target_id = "${local.app_name}-lambda"

  arn = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron_schedule.arn
}

# IAM
resource "aws_iam_role" "lambda_role" {
  name = "${local.app_name}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_role_policy" {
  name        = "${local.app_name}-role-policy"
  description = "Policy for Lambda to read/write to S3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.once_human_codes.arn}",
        "${aws_s3_bucket.once_human_codes.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_role_policy.arn
}
