# --- Terraform Configuration ---
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- Provider Definition ---
provider "aws" {
  region = var.aws_region
}

# --- Variables ---
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A unique name for the project used for resource naming"
  type        = string
  default     = "my-express-app"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use (recommend 3 for HA)"
  type        = number
  default     = 3
}

variable "app_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080 # Default for the example Dockerfile
}

variable "app_cpu" {
  description = "CPU units for the Fargate task (e.g., 256, 512, 1024)"
  type        = number
  default     = 512 # 0.5 vCPU
}

variable "app_memory" {
  description = "Memory in MiB for the Fargate task (e.g., 512, 1024, 2048)"
  type        = number
  default     = 1024 # 1 GB
}

variable "app_image_uri" {
  description = "URI of the Docker image in ECR (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-express-app:latest)"
  type        = string
  # Replace with your actual ECR image URI after building and pushing
  # default = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-express-app:latest"
}

variable "app_desired_count" {
  description = "Initial desired number of application tasks"
  type        = number
  default     = 2
}

variable "app_scaling_min_capacity" {
  description = "Minimum number of tasks for auto-scaling"
  type        = number
  default     = 2
}

variable "app_scaling_max_capacity" {
  description = "Maximum number of tasks for auto-scaling"
  type        = number
  default     = 6
}

variable "app_scaling_cpu_target" {
  description = "Target average CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "db_instance_class" {
  description = "Instance class for DocumentDB instances"
  type        = string
  default     = "db.t3.medium"
}

variable "db_instance_count" {
  description = "Number of DocumentDB instances (min 2 for HA recommended)"
  type        = number
  default     = 2
}

variable "db_name" {
  description = "Name for the DocumentDB database"
  type        = string
  default     = "mydatabase"
}

variable "domain_name" {
  description = "The custom domain name for the application (e.g., app.example.com)"
  type        = string
  # default     = "app.example.com" # Uncomment and set your domain
}

variable "root_domain_name" {
  description = "The root domain managed in Route 53 (e.g., example.com)"
  type        = string
  # default     = "example.com" # Uncomment and set your root domain
}

# --- Data Sources ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Networking ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index) # e.g., 10.0.0.0/24, 10.0.1.0/24, ...
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # For NAT Gateway placement

  tags = {
    Name        = "${var.project_name}-public-subnet-${data.aws_availability_zones.available.names[count.index]}"
    Tier        = "Public"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count) # e.g., 10.0.3.0/24, 10.0.4.0/24, ...
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${data.aws_availability_zones.available.names[count.index]}"
    Tier        = "Private"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_eip" "nat" {
  count = var.az_count
  domain   = "vpc" # Changed from `vpc = true` for newer provider versions

  tags = {
    Name        = "${var.project_name}-nat-eip-${data.aws_availability_zones.available.names[count.index]}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.project_name}-nat-gw-${data.aws_availability_zones.available.names[count.index]}"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-private-rt-${data.aws_availability_zones.available.names[count.index]}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- Security Groups ---
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol    = "-1" # Allow all outbound traffic
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg-${var.environment}"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-tasks-sg-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_security_group" "docdb" {
  name        = "${var.project_name}-docdb-sg-${var.environment}"
  description = "Allow traffic from ECS tasks to DocumentDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = 27017 # Default DocumentDB port
    to_port         = 27017
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-docdb-sg-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Secrets Manager ---
# Store the master password securely
resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}-db-credentials-${var.environment}"
  description = "DocumentDB master credentials"
  # Use a generated password for initial creation.
  # IMPORTANT: Consider managing the actual password rotation/updates outside initial Terraform apply
  # or using a more robust secret injection method via CI/CD.
  recovery_window_in_days = 7 # Set to 0 for force deletion without recovery (not recommended for prod)
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = <<EOF
{
  "username": "${var.project_name}admin",
  "password": "${random_password.db_master_password.result}"
}
EOF
  lifecycle {
    ignore_changes = [secret_string] # Prevent Terraform from overwriting password if changed externally/rotated
  }
}


# --- ECR Repository ---
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE" # Or IMMUTABLE if preferred

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# --- DocumentDB ---
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet-group-${var.environment}"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-docdb-subnet-group-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.project_name}-docdb-cluster-${var.environment}"
  engine                  = "docdb"
  master_username         = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["password"]
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.docdb.id]
  skip_final_snapshot     = true # Set to false for production safety
  backup_retention_period = 7    # Adjust as needed
  preferred_backup_window = "07:00-09:00"
  # enabled_cloudwatch_logs_exports = ["profiler", "audit"] # Optional: Enable specific logs

  tags = {
    Name        = "${var.project_name}-docdb-cluster-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }

  # Prevent accidental replacement if username/password changes in secrets manager
  # Let secrets manager handle rotation, app reads latest version
  lifecycle {
    ignore_changes = [master_username, master_password]
  }
}

resource "aws_docdb_cluster_instance" "main" {
  count              = var.db_instance_count
  identifier         = "${var.project_name}-docdb-instance-${var.environment}-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.db_instance_class
  # availability_zone = data.aws_availability_zones.available.names[count.index] # Let AWS distribute for better HA
  engine             = "docdb"

  tags = {
    Name        = "${var.project_name}-docdb-instance-${var.environment}-${count.index}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- IAM Roles for ECS ---
data "aws_iam_policy_document" "ecs_task_execution_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-ecs-execution-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role_policy.json
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # Allows pulling ECR images, sending logs to CW
}

# Policy allowing task to read DB credentials from Secrets Manager
data "aws_iam_policy_document" "ecs_task_secret_access" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.db_credentials.arn
    ]
  }
  # Add other permissions needed by the application here (e.g., S3 access)
}

resource "aws_iam_policy" "ecs_task_secret_access_policy" {
  name        = "${var.project_name}-ecs-secret-access-policy-${var.environment}"
  description = "Allow ECS task to access specific secrets"
  policy      = data.aws_iam_policy_document.ecs_task_secret_access.json
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-ecs-task-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role_policy.json # Assumed by ECS tasks
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_secret_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_secret_access_policy.arn
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 14 # Adjust as needed

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- ECS Cluster, Task Definition, Service ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.environment}"

  tags = {
    Name        = "${var.project_name}-cluster-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.app_cpu
  memory                   = var.app_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container-${var.environment}"
      image     = var.app_image_uri != "" ? var.app_image_uri : "${aws_ecr_repository.app.repository_url}:latest" # Use default if var not set
      cpu       = var.app_cpu
      memory    = var.app_memory
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port # Not used in awsvpc mode but required field
          protocol      = "tcp"
        }
      ]
      environment = [
        # Add non-sensitive environment variables here
        { name = "NODE_ENV", value = var.environment },
        { name = "PORT", value = tostring(var.app_port) },
        { name = "DB_NAME", value = var.db_name }, # Pass DB name if needed by app
        # DB Host is derived later if needed, but usually connection string is preferred
        { name = "DB_HOST", value = aws_docdb_cluster.main.endpoint }, # Example: Pass DB endpoint
        { name = "DB_PORT", value = tostring(aws_docdb_cluster.main.port) } # Example: Pass DB port
        # Application should construct connection string using these parts + credentials from secrets
      ]
      secrets = [
        # Inject the full secret JSON or specific keys
        # Option 1: Inject full secret JSON string - App needs to parse JSON
        # { name = "DB_CREDENTIALS_JSON", valueFrom = aws_secretsmanager_secret.db_credentials.arn }

        # Option 2: Inject individual keys (requires keys 'username' and 'password' in the secret)
         { name = "DB_USERNAME", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::" },
         { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::" }

        # Construct connection string in the app like:
        # mongodb://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false
        # Note: Ensure DocumentDB TLS is enabled (default) and CA cert is handled by Node driver or provided.
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs" # Prefix for log streams in the group
        }
      }
      # Add health check if your container supports it
      # healthCheck = {
      #   command = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/health || exit 1"] # Example
      #   interval = 30
      #   timeout = 5
      #   retries = 3
      #   startPeriod = 60
      # }
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-def-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Application Load Balancer ---
# Assuming ACM certificate is pre-provisioned or managed elsewhere
# Use data source if pre-provisioned, or aws_acm_certificate + aws_acm_certificate_validation if creating here
data "aws_acm_certificate" "cert" {
  count       = var.domain_name != "" ? 1 : 0
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false # Set to true for production

  tags = {
    Name        = "${var.project_name}-alb-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg-${var.environment}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Required for Fargate

  health_check {
    enabled             = true
    interval            = 30
    path                = "/" # Adjust to your app's health check endpoint
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399" # Expect successful HTTP status codes
  }

  tags = {
    Name        = "${var.project_name}-tg-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = var.domain_name != "" ? 1 : 0 # Only create if domain is specified
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Choose appropriate policy
  certificate_arn   = data.aws_acm_certificate.cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Fallback listener if no domain/cert specified (e.g., for testing) - less secure
resource "aws_lb_listener" "http_fallback" {
  count             = var.domain_name == "" ? 1 : 0 # Only create if domain is NOT specified
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs_tasks.id]
    # assign_public_ip = false # Default for Fargate in private subnet
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project_name}-container-${var.environment}" # Must match container name in task def
    container_port   = var.app_port
  }

  # Ensure ALB listener depends on the service being ready if needed (often handled implicitly by target group registration)
  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener.http_fallback, # Ensure listener exists before service tries to register
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_iam_role_policy_attachment.ecs_task_secret_access
  ]

  # Optional: Enable service discovery or deployment strategies (Blue/Green)
  # deployment_controller {
  #   type = "ECS" # or CODE_DEPLOY for Blue/Green
  # }
  # health_check_grace_period_seconds = 60 # Allow time for container startup

  tags = {
    Name        = "${var.project_name}-service-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [desired_count] # Allow auto-scaling to manage desired count
  }
}

# --- ECS Auto Scaling ---
resource "aws_appautoscaling_target" "ecs_service" {
  min_capacity       = var.app_scaling_min_capacity
  max_capacity       = var.app_scaling_max_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu_scaling" {
  name               = "${var.project_name}-cpu-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.app_scaling_cpu_target
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300 # Cooldown period in seconds after scale-in
    scale_out_cooldown = 60  # Cooldown period in seconds after scale-out
  }
}

# --- Static Assets (S3 + CloudFront) ---
resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.project_name}-static-assets-${var.environment}" # Bucket names must be globally unique
  # acl    = "private" # Recommended to use OAI or Bucket Policy

  tags = {
    Name        = "${var.project_name}-static-assets-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${aws_s3_bucket.static_assets.id}"
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_assets.arn}/*"] # Access to objects in the bucket

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_oai" {
  bucket = aws_s3_bucket.static_assets.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.static_assets.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for ${var.project_name} static assets"
  default_root_object = "index.html" # If you have a root object

  # Use domain name for CDN if provided
  aliases = var.domain_name != "" ? ["static.${var.domain_name}"] : [] # Example: static.app.example.com

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_assets.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600 # 1 hour
    max_ttl                = 86400 # 24 hours
    compress               = true # Enable compression for text files
  }

  # Restrict viewer access (Geo-restriction, etc. - optional)
  # restrictions {
  #   geo_restriction {
  #     restriction_type = "none" # Or "whitelist" / "blacklist"
  #   }
  # }

  viewer_certificate {
    # Use ACM cert if domain is specified and matches CloudFront alias
    acm_certificate_arn      = var.domain_name != "" ? data.aws_acm_certificate.cert[0].arn : null
    ssl_support_method       = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version = var.domain_name != "" ? "TLSv1.2_2021" : "TLSv1" # Default if no domain
    cloudfront_default_certificate = var.domain_name == "" ? true : null # Use default *.cloudfront.net cert if no custom domain
  }

  tags = {
    Name        = "${var.project_name}-cdn-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_s3_bucket_policy.allow_oai]
}


# --- Route 53 DNS Records ---
data "aws_route53_zone" "selected" {
  count        = var.root_domain_name != "" ? 1 : 0
  name         = var.root_domain_name
  private_zone = false
}

# Alias record for the ALB (e.g., app.example.com)
resource "aws_route53_record" "app" {
  count   = var.domain_name != "" && var.root_domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Alias record for the CloudFront Distribution (e.g., static.app.example.com)
resource "aws_route53_record" "cdn" {
  count   = var.domain_name != "" && var.root_domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = "static.${var.domain_name}" # Matches CloudFront alias
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false # CloudFront doesn't expose health status via DNS alias
  }
}


# --- Outputs ---
output "alb_dns_name" {
  value = try(aws_lb.main.dns_name, "N/A")
  description = "alb_dns_name"
}

output "cloudfront_domain_name" {
  value = try(aws_cloudfront_distribution.s3_distribution.domain_name, "N/A")
  description = "cloudfront_domain_name"
}

output "documentdb_cluster_endpoint" {
  value = try(aws_docdb_cluster.main.endpoint, "N/A")
  description = "documentdb_cluster_endpoint"
}

output "documentdb_cluster_reader_endpoint" {
  value = try(aws_docdb_cluster.main.reader_endpoint, "N/A")
  description = "documentdb_cluster_reader_endpoint"
}

output "db_credentials_secret_arn" {
  value = try(aws_secretsmanager_secret.db_credentials.arn, "N/A")
  description = "db_credentials_secret_arn"
}

output "ecr_repository_url" {
  value = try(aws_ecr_repository.app.repository_url, "N/A")
  description = "ecr_repository_url"
}

output "static_assets_s3_bucket_name" {
  value = try(aws_s3_bucket.static_assets.id, "N/A")
  description = "static_assets_s3_bucket_name"
}

output "application_url" {
  description = "URL to access the application (if custom domain is configured)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "static_assets_url" {
  description = "URL to access static assets via CloudFront (if custom domain is configured)"
  value       = var.domain_name != "" ? "https://static.${var.domain_name}" : "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}