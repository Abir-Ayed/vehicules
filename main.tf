resource "aws_s3_bucket" "json_bucket" {
  bucket = var.bucket_name


   tags = merge(
    {
      Name        = "Vehicle JSON Bucket",
      Environment = var.environment,

    },
  
  )
}
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.bucket_name


   tags = merge(
    {
      Name        = "deployment Bucket",
      Environment = var.environment,

    },
  
  )
}
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.json_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}
resource "aws_s3_bucket_policy" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}
# Create the Lambda function
resource "aws_lambda_function" "extract_json" {
  function_name = "ExtractJsonFunction"
  runtime       = "python3.9"  # Specify your runtime
  handler       = "lambda_function.lambda_handler"  # Update based on your code
  role          = aws_iam_role.lambda_exec.arn
  s3_bucket     = aws_s3_bucket.json_bucket.bucket
  s3_key        = "lambda_function.zip"  # Path to your deployment package
    environment {
    variables = {
      RDS_HOST     = "rds-endpoint"
      DB_USERNAME  = "username"
      DB_PASSWORD  = "password"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"  # Allows Lambda to assume this role
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

# Attach the policy for S3 access to the Lambda function
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy"
  description = "Policy for Lambda to access S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",   # Read permissions for S3
          "s3:ListBucket"   # List permissions for S3 bucket
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.lambda_bucket.arn,             
          "${aws_s3_bucket.lambda_bucket.arn}/*"       
        ]
      }
    ]
  })
}

# Attach CloudWatch Logs policy to the Lambda function
resource "aws_iam_policy" "lambda_cloudwatch_policy" {
  name        = "lambda_cloudwatch_policy"
  description = "Policy for Lambda to write logs to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"  # Allows logging across CloudWatch Logs
      }
    ]
  })
}

# Attach both policies to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_policy.arn
}
#s3 event notification
resource "aws_lambda_permission" "allow_s3_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.extract_json.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.lambda_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.lambda_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.extract_json.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
#  Create an IAM Role for QuickSight
resource "aws_iam_role" "quicksight_role" {
  name = "quicksight-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "quicksight.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "quicksight_policy" {
  role = aws_iam_role.quicksight_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds:DescribeDBInstances",
          "rds:Connect"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "quicksight:DescribeDataSets",
          "quicksight:DescribeAnalysis",
          "quicksight:ListDashboards"
        ],
        Resource = "*"
      }
    ]
  })
}
resource "aws_security_group" "rds_quicksight_sg" {
  name        = "allow-quicksight-rds-access"
  description = "Security group to allow access from AWS QuickSight to RDS"
  vpc_id      = "your_vpc_id"

  # Allow QuickSight to access the RDS instance on port 5432 (PostgreSQL)
  ingress {
    description = "Allow QuickSight access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"

    # Replace with the QuickSight IP ranges for your region
    cidr_blocks = [
      "52.23.63.224/27",   # Example for us-east-1, refer to AWS documentation for your region
      "34.205.244.224/27"
    ]
  }

  # Allow internal communication within the VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Créer une instance RDS PostgreSQL
resource "aws_db_instance" "my_rds_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "13.3"  # Version de PostgreSQL
  instance_class       = "db.t3.micro"
  db_name                 = "vehicules"
  username             = "dbuser"
  password             = "dbpassword"
  port                 = 5432
  publicly_accessible  = true
  skip_final_snapshot  = true

  # Référence du Security Group
  vpc_security_group_ids = [aws_security_group.rds_sg.id]



  tags = {
    Name = "providers"
  }
}

# Security Group pour l'instance RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds_security_group"
  description = "Security group for RDS allowing PostgreSQL access"

  # Autorise l'accès au port PostgreSQL depuis QuickSight (ou tout autre service)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"

    cidr_blocks = ["10.0.0.0/16"]  
  
    security_groups = [aws_security_group.rds_quicksight_sg.id]  
  }

  # Autorise tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

