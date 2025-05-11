terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A name for the project to prefix resources"
  type        = string
  default     = "expressapp"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "List of Availability Zones to use"
  type        = list(string)
  # Ensure these match your chosen region and number of subnets
  default = ["us-east-1a", "us-east-1b"]
}

variable "app_instance_type" {
  description = "EC2 instance type for the application"
  type        = string
  default     = "t3.small"
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 3000 # Default for many Node.js apps
}

variable "db_instance_class" {
  description = "Instance class for DocumentDB"
  type        = string
  default     = "db.t3.medium" # Smallest recommended for production
}

variable "db_username" {
  description = "Master username for DocumentDB (will be stored in Secrets Manager)"
  type        = string
  default     = "docdbadmin"
}

# Generate a random password for DocumentDB if not provided
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = "production" # Or "staging", "dev"
    ManagedBy   = "Terraform"
  }
}

#------------------------------------------------------------------------------
# VPC and Networking
#------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.project_name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Useful for bastion, not strictly needed for NAT GW hosts
  tags                    = merge(local.common_tags, { Name = "${var.project_name}-public-subnet-${count.index + 1}" })
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags                    = merge(local.common_tags, { Name = "${var.project_name}-private-subnet-${count.index + 1}" })
}

resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs) # One NAT GW per AZ for HA
  domain = "vpc" # domain was deprecated, use vpc_ipv4_cidr_block_association_id if needed or just "vpc"
  tags  = merge(local.common_tags, { Name = "${var.project_name}-nat-eip-${count.index + 1}" })
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.common_tags, { Name = "${var.project_name}-nat-gw-${count.index + 1}" })
  depends_on    = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id # Route to NAT GW in the same AZ
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-private-rt-${count.index + 1}" })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#------------------------------------------------------------------------------
# Security Groups
#------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-alb-sg" })
}

resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Allow traffic to application instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  # Optional: Allow SSH from a bastion or specific IP
  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["YOUR_BASTION_IP/32"] # Replace with your IP or bastion SG
  # }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allows outbound to internet (via NAT) and other AWS services
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-app-sg" })
}

resource "aws_security_group" "docdb_sg" {
  name        = "${var.project_name}-docdb-sg"
  description = "Allow traffic to DocumentDB cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 27017 # MongoDB default port
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Only allow from app servers
  }
  egress { # Not strictly necessary for DocumentDB, but good for consistency
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-docdb-sg" })
}

#------------------------------------------------------------------------------
# IAM Roles and Policies
#------------------------------------------------------------------------------
resource "aws_iam_role" "app_ec2_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = merge(local.common_tags, { Name = "${var.project_name}-ec2-role" })
}

# Policy for CloudWatch Agent and basic SSM access
resource "aws_iam_policy" "app_ec2_policy" {
  name        = "${var.project_name}-ec2-policy"
  description = "Policy for EC2 instances to access CloudWatch, Secrets Manager, and SSM"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/*" # For SSM Parameter Store if used
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_creds.arn # Specific to the DB secret
      }
      # Add S3 access if pulling code from S3
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "s3:GetObject"
      #   ],
      #   Resource = "arn:aws:s3:::your-app-code-bucket/*"
      # }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_ec2_role_policy_attach" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = aws_iam_policy.app_ec2_policy.arn
}

# Attach AWS managed policy for SSM Core for Session Manager access (recommended)
resource "aws_iam_role_policy_attachment" "ssm_core_policy_attach" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.app_ec2_role.name
  tags = merge(local.common_tags, { Name = "${var.project_name}-ec2-profile" })
}

#------------------------------------------------------------------------------
# Secrets Manager for DB Credentials
#------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_creds" {
  name        = "${var.project_name}/docdb/master_creds"
  description = "DocumentDB master credentials for ${var.project_name}"
  tags        = merge(local.common_tags, { Name = "${var.project_name}-docdb-creds" })
}

resource "aws_secretsmanager_secret_version" "db_creds_version" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
  })
}

#------------------------------------------------------------------------------
# DocumentDB Cluster
#------------------------------------------------------------------------------
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = merge(local.common_tags, { Name = "${var.project_name}-docdb-subnet-group" })
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.project_name}-docdb-cluster"
  engine                  = "docdb"
  master_username         = jsondecode(aws_secretsmanager_secret_version.db_creds_version.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.db_creds_version.secret_string)["password"]
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.docdb_sg.id]
  skip_final_snapshot     = true # Set to false for production
  backup_retention_period = 7    # Adjust as needed
  preferred_backup_window = "07:00-09:00"
  storage_encrypted       = true
  # engine_version          = "4.0.0" # Or "5.0.0", check latest supported
  tags                    = merge(local.common_tags, { Name = "${var.project_name}-docdb-cluster" })
}

resource "aws_docdb_cluster_instance" "main" {
  count              = 2 # For High Availability, minimum 2 instances
  identifier         = "${var.project_name}-docdb-instance-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.db_instance_class
  engine             = "docdb"
  tags               = merge(local.common_tags, { Name = "${var.project_name}-docdb-instance-${count.index + 1}" })
}

#------------------------------------------------------------------------------
# Application Load Balancer (ALB)
#------------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
  enable_deletion_protection = false # Set to true for production
  tags               = merge(local.common_tags, { Name = "${var.project_name}-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/" # Adjust to your app's health check endpoint
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout_seconds     = 5
    interval_seconds    = 30
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-app-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
  # For HTTPS, you would add another listener on port 443 and reference an ACM certificate
  # certificate_arn = "arn:aws:acm:REGION:ACCOUNT_ID:certificate/CERTIFICATE_ID"
}

#------------------------------------------------------------------------------
# EC2 Launch Template and Auto Scaling Group
#------------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.app_instance_type
  key_name      = null # Add your key pair name if you need SSH access directly

  iam_instance_profile {
    arn = aws_iam_instance_profile.app_ec2_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = false # Instances are in private subnets
    security_groups             = [aws_security_group.app_sg.id]
  }

  # User data script to install Node.js, CloudWatch Agent, and run the application
  # THIS IS A SIMPLIFIED SCRIPT. In production, use CodeDeploy or bake AMIs.
  # Assumes your app is in a 'server' directory and main file is 'app.js' or 'index.js'
  # and package.json has a 'start' script.
  user_data = base64encode(<<-EOF
#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Install Node.js (e.g., Node.js 18)
yum update -y
curl -sL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs gcc-c++ make

# Install CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Create CloudWatch Agent config (minimal example, customize as needed)
cat <<'CWAGENTCONFIG' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${var.project_name}-app-user-data-logs",
            "log_stream_name": "{instance_id}-user-data"
          },
          {
            "file_path": "/opt/app/logs/app.log",  # CHANGE THIS TO YOUR APP'S LOG FILE
            "log_group_name": "${var.project_name}-application-logs",
            "log_stream_name": "{instance_id}-app"
          },
          {
            "file_path": "/opt/app/logs/error.log", # CHANGE THIS TO YOUR APP'S ERROR LOG FILE
            "log_group_name": "${var.project_name}-application-error-logs",
            "log_stream_name": "{instance_id}-error"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
        "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
        "ImageId": "$${aws:ImageId}",
        "InstanceId": "$${aws:InstanceId}",
        "InstanceType": "$${aws:InstanceType}"
    },
    "metrics_collected": {
        "collectd": {
            "metrics_aggregation_interval": 60
        },
        "disk": {
            "measurement": [
                "used_percent"
            ],
            "metrics_collection_interval": 60,
            "resources": [
                "*"
            ]
        },
        "mem": {
            "measurement": [
                "mem_used_percent"
            ],
            "metrics_collection_interval": 60
        }
    }
  }
}
CWAGENTCONFIG

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

# Application Setup
APP_DIR="/opt/app"
mkdir -p $APP_DIR/logs # Create logs directory if your app logs to files

# --- BEGIN: Application Deployment Placeholder ---
# In a real scenario, you'd pull code from S3, CodeCommit, GitHub, or use a pre-baked AMI.
# This is a placeholder to simulate fetching and running an app.
# Create a dummy package.json and server.js
echo "Fetching application code (placeholder)..."
mkdir -p $APP_DIR/server
mkdir -p $APP_DIR/public

# Dummy package.json
cat << 'PACKAGEJSON' > $APP_DIR/package.json
{
  "name": "my-express-app",
  "version": "1.0.0",
  "description": "",
  "main": "server/app.js",
  "scripts": {
    "start": "node server/app.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.17.1",
    "mongodb": "^4.0.0"  # Ensure your actual app has this or similar for DocumentDB
  },
  "author": "",
  "license": "ISC"
}
PACKAGEJSON

# Dummy server/app.js - THIS IS CRITICAL. Modify to use your actual application code.
# It needs to fetch DB credentials from Secrets Manager.
cat << 'APPJS' > $APP_DIR/server/app.js
const express = require('express');
const { MongoClient } = require('mongodb');
const AWS = require('aws-sdk'); // AWS SDK is pre-installed on EC2 AMIs

const app = express();
const port = ${var.app_port}; // Use the port variable

const secretsManager = new AWS.SecretsManager({ region: '${var.aws_region}' });
const secretName = '${aws_secretsmanager_secret.db_creds.name}';

let db;

async function getSecret() {
  try {
    const data = await secretsManager.getSecretValue({ SecretId: secretName }).promise();
    if ('SecretString' in data) {
      return JSON.parse(data.SecretString);
    }
    throw new Error("SecretString not found");
  } catch (err) {
    console.error("Error retrieving secret: ", err);
    throw err;
  }
}

async function connectToDB() {
  try {
    const credentials = await getSecret();
    const dbUser = credentials.username;
    const dbPassword = credentials.password;
    const dbEndpoint = process.env.DB_ENDPOINT || '${aws_docdb_cluster.main.endpoint}'; // Fallback to Terraform output during build
    const dbName = process.env.DB_NAME || '${var.project_name}db';

    // For DocumentDB, the connection string might need ?tls=true&replicaSet=rs0&readPreference=secondaryPreferred
    // Check DocumentDB documentation for the exact connection string format.
    // The caFilePath part is tricky with user data; often it's easier to disable TLS for non-prod or download the CA cert.
    // For production, ensure TLS is correctly configured.
    // const mongoURI = `mongodb://${dbUser}:${encodeURIComponent(dbPassword)}@${dbEndpoint}:27017/${dbName}?tls=true&tlsCAFile=\`pwd\`/rds-combined-ca-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred`;
    // Simpler connection string for example (TLS disabled, not for production without proper setup)
    const mongoURI = `mongodb://${dbUser}:${encodeURIComponent(dbPassword)}@${dbEndpoint}:27017/${dbName}?ssl=true&ssl_ca_certs=rds-combined-ca-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred`;

    // Download the CA bundle if not already on the AMI. Amazon Linux 2 AMIs usually have it.
    // Or you can download it explicitly:
    if (!require('fs').existsSync('rds-combined-ca-bundle.pem')) {
      console.log('Downloading CA bundle...');
      require('child_process').execSync('wget https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem');
    }
    
    const client = new MongoClient(mongoURI);
    await client.connect();
    db = client.db(dbName);
    console.log('Successfully connected to DocumentDB!');
  } catch (err) {
    console.error('Failed to connect to DocumentDB:', err);
    // Application might not start correctly or handle DB connection errors gracefully
    process.exit(1); // Exit if DB connection fails to prevent app from running in a bad state
  }
}

// Middleware to parse JSON bodies
app.use(express.json());

// Serve static files from 'public' directory
app.use(express.static('public'));

app.get('/', (req, res) => {
  res.send('Hello from Express on AWS with DocumentDB! Try /data for DB test.');
});

app.get('/health', (req, res) => {
  // Basic health check. Could be extended to check DB connection.
  res.status(200).send('OK');
});

app.get('/data', async (req, res) => {
  if (!db) {
    return res.status(500).send('Database not connected');
  }
  try {
    const collection = db.collection('testcollection');
    const docCount = await collection.countDocuments();
    await collection.insertOne({ message: 'Hello from app', timestamp: new Date() });
    res.send(`DocumentDB connected. Collection 'testcollection' has ${docCount + 1} documents now.`);
  } catch (error) {
    console.error("Error accessing DB: ", error);
    res.status(500).send('Error accessing database: ' + error.message);
  }
});

// Ensure DB connection is established before starting the server
connectToDB().then(() => {
  app.listen(port, () => {
    console.log(\`App listening at http://localhost:\${port}\`);
    // Log to file that application logs to, e.g. /opt/app/logs/app.log
    // This is just an example; use a proper logging library like Winston
    require('fs').appendFileSync('/opt/app/logs/app.log', \`App started on port \${port} at \${new Date().toISOString()}\\n\`);
  });
}).catch(err => {
  console.error("Failed to start server due to DB connection error:", err);
  // Log to error file
  require('fs').appendFileSync('/opt/app/logs/error.log', \`Failed to start server: \${err.message} at \${new Date().toISOString()}\\n\`);
});
APPJS

# Dummy public/index.html
cat << 'INDEXHTML' > $APP_DIR/public/index.html
<!DOCTYPE html>
<html>
<head><title>My Express App</title></head>
<body><h1>Welcome!</h1><p>This is a static HTML page.</p></body>
</html>
INDEXHTML

# Install application dependencies
echo "Installing application dependencies..."
cd $APP_DIR
# If your project uses yarn, install yarn first: npm install -g yarn; yarn install
npm install

# Set environment variables (can also be done via systemd unit file or pm2 ecosystem file)
# The DB_ENDPOINT can be injected here or discovered via SDK if more dynamic setup is needed.
export DB_ENDPOINT="${aws_docdb_cluster.main.endpoint}"
export DB_NAME="${var.project_name}db"
export PORT="${var.app_port}"
# Add any other environment variables your application needs

# Start application using pm2 (recommended for Node.js process management)
echo "Starting application with pm2..."
npm install pm2 -g
# Create an ecosystem file for more robust configuration
cat << 'ECOSYSTEMJS' > $APP_DIR/ecosystem.config.js
module.exports = {
  apps : [{
    name   : "${var.project_name}-app",
    script : "$APP_DIR/server/app.js", // Or your main file
    cwd    : "$APP_DIR",
    env: {
      NODE_ENV: "production", // Or "development"
      PORT: ${var.app_port},
      DB_ENDPOINT: "${aws_docdb_cluster.main.endpoint}",
      DB_NAME: "${var.project_name}db",
      // Add other env vars here
    },
    log_date_format : "YYYY-MM-DD HH:mm Z",
    out_file : "$APP_DIR/logs/app.log",    // Path to your app's stdout log
    error_file : "$APP_DIR/logs/error.log" // Path to your app's stderr log
  }]
}
ECOSYSTEMJS

pm2 start $APP_DIR/ecosystem.config.js
pm2 startup systemd # To ensure pm2 restarts on boot
pm2 save

echo "User data script finished."
# --- END: Application Deployment Placeholder ---
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-app-instance" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-app-volume" })
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-lt" })
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id # Deploy in private subnets
  desired_capacity    = 2
  min_size            = 2 # For HA
  max_size            = 5 # Adjust as needed

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn]
  health_check_type = "ELB" # Use ELB health checks in addition to EC2
  health_check_grace_period = 300 # Allow time for instance to start and pass health checks

  # Auto Scaling Policy (example: based on CPU utilization)
  # You can create more sophisticated policies based on other metrics
  tags = concat(
    [for k, v in local.common_tags : { key = k, value = v, propagate_at_launch = true }],
    [{ key = "Name", value = "${var.project_name}-app-instance", propagate_at_launch = true }]
  )
}

resource "aws_autoscaling_policy" "cpu_scaling_policy" {
  name                   = "${var.project_name}-cpu-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup = 300 # Time in seconds for a new instance to warm up

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0 # Target average CPU utilization (e.g., 70%)
  }
}

#------------------------------------------------------------------------------
# (Optional) Route 53 for DNS
#------------------------------------------------------------------------------
# data "aws_route53_zone" "primary" {
#   name         = "yourdomain.com." # Replace with your domain name
#   private_zone = false
# }

# resource "aws_route53_record" "app_dns" {
#   zone_id = data.aws_route53_zone.primary.zone_id
#   name    = "app.${data.aws_route53_zone.primary.name}" # e.g., app.yourdomain.com
#   type    = "A"

#   alias {
#     name                   = aws_lb.main.dns_name
#     zone_id                = aws_lb.main.zone_id
#     evaluate_target_health = true
#   }
# }

#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------
output "alb_dns_name" {
  value = try(aws_lb.main.dns_name, "N/A")
  description = "alb_dns_name"
}

output "docdb_cluster_endpoint" {
  value = try(aws_docdb_cluster.main.endpoint, "N/A")
  description = "docdb_cluster_endpoint"
}

output "docdb_cluster_reader_endpoint" {
  value = try(aws_docdb_cluster.main.reader_endpoint, "N/A")
  description = "docdb_cluster_reader_endpoint"
}

output "docdb_master_credentials_secret_arn" {
  value = try(aws_secretsmanager_secret.db_creds.arn, "N/A")
  description = "docdb_master_credentials_secret_arn"
}

output "app_ec2_role_arn" {
  value = try(aws_iam_role.app_ec2_role.arn, "N/A")
  description = "app_ec2_role_arn"
}

output "cloudwatch_app_log_group_user_data" {
  description = "CloudWatch Log Group name for user data logs"
  value       = "${var.project_name}-app-user-data-logs"
}

output "cloudwatch_app_log_group_application" {
  description = "CloudWatch Log Group name for application logs (example)"
  value       = "${var.project_name}-application-logs"
}