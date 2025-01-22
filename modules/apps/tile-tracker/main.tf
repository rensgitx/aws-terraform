data "aws_caller_identity" "current" {}

/* Lambda layer and lambda function packages should be uploaded first to below paths */
data "aws_s3_object" "tile_tracker_lambda_function" {
  bucket              = "${var.tile_tracker_bucket}"
  key                 = "tile-tracker/lambda/lambda_function-${var.env}.py.zip"
}

data "aws_s3_object" "tile_tracker_lambda_layer" {
  bucket              = "${var.tile_tracker_bucket}"
  key                 = "tile-tracker/lambda/layer_content-${var.env}.zip"
}

/* Lambda layer */
resource "aws_lambda_layer_version" "tile_tracker_lambda_layer" {
  layer_name          = "tile-tracker-python-layer-${var.env}"
  description         = "Python layer for lambda"
  s3_bucket           = data.aws_s3_object.tile_tracker_lambda_layer.bucket
  s3_key              = data.aws_s3_object.tile_tracker_lambda_layer.key
  compatible_runtimes = ["python3.11"] 
}

/* Lambda function */
resource "aws_iam_role" "tile_tracker_lambda_role" {
  name        = "tile-tracker-lambda-role-${var.env}"
  description = "Lambda execution role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
          AWS     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "tile_tracker_lambda_policy" {
  name        = "tile-tracker-lambda-policy-${var.env}"
  description = "Policy for lambda execution role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CloudWatchAccess"
        Effect   = "Allow"
        Action   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid = "WriteToS3",
        Action = [
            "s3:PutObject",
            "s3:GetObject",
        ],
        Effect = "Allow",
        Resource = [
            "arn:aws:s3:::${var.tile_tracker_bucket}/tile-tracker/data/",
            "arn:aws:s3:::${var.tile_tracker_bucket}/tile-tracker/data/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tile_tracker_lambda_policy_attachment" {
  role       = aws_iam_role.tile_tracker_lambda_role.name
  policy_arn = aws_iam_policy.tile_tracker_lambda_policy.arn
}

resource "aws_lambda_function" "tile_tracker_lambda_function" {
  function_name    = "tile-tracker-lambda-function-${var.env}"
  description      = "Lambda function to retrieve Tile location"
  s3_bucket        = data.aws_s3_object.tile_tracker_lambda_function.bucket
  s3_key           = data.aws_s3_object.tile_tracker_lambda_function.key
  source_code_hash = data.aws_s3_object.tile_tracker_lambda_function.etag
  role             = aws_iam_role.tile_tracker_lambda_role.arn
  handler          = "lambda_runner.lambda_handler"
  runtime          = "python3.11"
  timeout          = 10
  layers           = [aws_lambda_layer_version.tile_tracker_lambda_layer.arn]
  architectures    = ["x86_64"]

  environment {
    variables = {
      TILE_EMAIL    = var.tile_email
      TILE_PASSWORD = var.tile_password
      ENV           = var.env
    }
  }
}


/* EventBridge Scheduler */
resource "aws_iam_role" "tile_tracker_eventbridge_scheduler_role" {
  name = "tile-tracker-eventbridge-scheduler-role-${var.env}"
  description = "Eventbridge scheduler role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com"
          AWS     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "tile_tracker_eventbridge_scheduler_policy" {
  name        = "tile-tracker-eventbridge-scheduler-policy-${var.env}"
  description = "Allow EventBridge Scheduler to invoke the Lambda function"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = aws_lambda_function.tile_tracker_lambda_function.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tile_tracker_eventbridge_scheduler_policy_attachment" {
  role       = aws_iam_role.tile_tracker_eventbridge_scheduler_role.name
  policy_arn = aws_iam_policy.tile_tracker_eventbridge_scheduler_policy.arn
}

resource "aws_scheduler_schedule" "tile_tracker_lambda_scheduler" {
  name        = "tile-tracker-lambda-scheduler-${var.env}"
  description = "Invoke Lambda function every 15 minutes"
  schedule_expression = "cron(*/15 * * * ? *)"

  flexible_time_window {
    mode = "FLEXIBLE"
    maximum_window_in_minutes = 5
  }

  target {
    arn = aws_lambda_function.tile_tracker_lambda_function.arn
    role_arn = aws_iam_role.tile_tracker_eventbridge_scheduler_role.arn
    retry_policy {
      maximum_retry_attempts = 1
      maximum_event_age_in_seconds = 900
    }
  }
}

/* CloudWatch Alarms */
# SNS topic
resource "aws_sns_topic" "tile_tracker_notify_topic" {
  name = "tile-tracker-notify-topic-${var.env}"
}

# SNS topic policy
resource "aws_sns_topic_policy" "tile_tracker_notify_topic_policy" {
  arn = aws_sns_topic.tile_tracker_notify_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Sid     = "TileTrackerTopicPolicy"
    Effect  = "Allow",
    Principal = {
      Service = "cloudwatch.amazonaws.com"
      AWS     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
    }
    Action    = "SNS:Publish"
  })
}

# Subscribe an email to the SNS topic
resource "aws_sns_topic_subscription" "tile_tracker_email_subscription" {
  topic_arn = aws_sns_topic.tile_tracker_notify_topic.arn
  protocol  = "email"
  endpoint  = var.tile_notification_email
}

# Create the CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "tile_tracker_low_invocation" {
  alarm_name          = "tile-tracker-alarm-low-invocation-${var.env}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 3600 # seconds
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Lambda invocation rate is fewer than threshold in the last hour."

  dimensions = {
    FunctionName = aws_lambda_function.tile_tracker_lambda_function.id
  }
}

resource "aws_cloudwatch_metric_alarm" "tile_tracker_high_invocation" {
  alarm_name          = "tile-tracker-alarm-high-invocation-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 3600 # seconds
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  statistic           = "Sum"
  threshold           = 6
  alarm_description   = "Lambda invocation rate is more than threshold in the last hour."

  dimensions = {
    FunctionName = aws_lambda_function.tile_tracker_lambda_function.id
  }
}

# Composite alarm - triggers SNS when breached
resource "aws_cloudwatch_composite_alarm" "tile_tracker_invocation_anomaly" {
  alarm_name        = "tile-tracker-alarm-invocation-anomaly-${var.env}"
  alarm_description = "Invocation rate anomaly for tile-tracker lambda in the last 1 hour."
  alarm_rule        = <<-RULE
    ALARM(${aws_cloudwatch_metric_alarm.tile_tracker_low_invocation.alarm_name}) OR 
    ALARM(${aws_cloudwatch_metric_alarm.tile_tracker_high_invocation.alarm_name})
  RULE

  actions_enabled     = true
  alarm_actions = [
    aws_sns_topic.tile_tracker_notify_topic.arn
  ]
  insufficient_data_actions = []
  ok_actions          = []
}
