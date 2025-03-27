# Configure AWS provider

provider "aws" {
    region = "us-east-1"
}

# S3 Bucket

resource "aws_s3_bucket" "s3-bucket1" {
    bucket = "terraform-s3-bucket011"
}

# VPC

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
}

# IGW

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
}
# Subnet in VPC

resource "aws_subnet" "main_subnet" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
}

# Route Table

resource "aws_route_table" "main_route_table" {
    vpc_id = aws_vpc.main.id
}

# Route to Public Subnet

resource "aws_route" "internet_access" {
    route_table_id = aws_route_table.main_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
}

# Associate Route Table to Subnet

resource "aws_route_table_association" "subnet_association" {
    subnet_id = aws_subnet.main_subnet.id
    route_table_id = aws_route_table.main_route_table.id
}

# Security Group

resource "aws_security_group" "allow_ssh" {
    name = "allow_ssh"
    description = "Allow SSH inbound"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Launch Templates

resource "aws_launch_template" "launch_template" {
    name = "terraform-launch_template"
    image_id = "ami-071226ecf16aa7d96"
    instance_type = "t2.micro"
    key_name = "terraform_key_01"
    vpc_security_group_ids = [aws_security_group.allow_ssh.id]
    user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    service httpd start
    chkconfig httpd on
    echo '<html>
                    <head>
                        <title>Welcome to Auto Scaling EC2</title>
                        <style>
                            body {
                                font-family: Arial, sans-serif;
                                background-color: #f4f4f4;
                                margin: 0;
                                padding: 0;
                            }
                            .container {
                                max-width: 800px;
                                margin: 50px auto;
                                background-color: white;
                                padding: 30px;
                                border-radius: 8px;
                                box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
                            }
                            h1 {
                                color: #333;
                                text-align: center;
                            }
                            p {
                                color: #666;
                                font-size: 1.2em;
                                text-align: center;
                            }
                            .button {
                                display: inline-block;
                                padding: 10px 20px;
                                margin-top: 20px;
                                background-color: #4CAF50;
                                color: white;
                                font-size: 1.2em;
                                text-decoration: none;
                                border-radius: 5px;
                                text-align: center;
                            }
                            .button:hover {
                                background-color: #45a049;
                            }
                        </style>
                    </head>
                    <body>
                        <div class="container">
                            <h1>Welcome to Your Auto Scaling EC2 Instance!</h1>
                            <p>This page is being served by an EC2 instance launched by Auto Scaling.</p>
                            <p>Enjoy your auto-scaled environment!</p>
                            <a href="https://www.example.com" class="button">Visit Our Website</a>
                        </div>
                    </body>
                </html>' > /var/www/html/index.html
    EOF
    )

    lifecycle {
    create_before_destroy = true
    }
}

# Auto Scaling Group

resource "aws_autoscaling_group" "terraform-asg" {
    desired_capacity = 1
    max_size = 2
    min_size = 1
    vpc_zone_identifier = [aws_subnet.main_subnet.id]
    launch_template {
    id = aws_launch_template.launch_template.id
    version = "$Latest"
    }
    health_check_type = "EC2"
    health_check_grace_period = 300
    force_delete = true

    tag {
    key = "Name"
    value = "AutoScalingInstance01"
    propagate_at_launch = true 
    }
}

# ASG Policies

resource "aws_autoscaling_policy" "scale_up" {
    name = "scale_up"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    metric_aggregation_type = "Average"
    autoscaling_group_name = aws_autoscaling_group.terraform-asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
    name = "scale_down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    metric_aggregation_type = "Average"
    autoscaling_group_name = aws_autoscaling_group.terraform-asg.name
}

# CloudWatch

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
    alarm_name = "CloudWatch_Alarm"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 1
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 60
    statistic = "Average"
    threshold = 75
    alarm_actions = [aws_autoscaling_policy.scale_up.arn]
    dimensions = {
    autoscaling_group_name = aws_autoscaling_group.terraform-asg.name
    }
}

# Output EC2 instance ID

output "instance_id" {
    value = aws_launch_template.launch_template.id
}

output "ec2_public_ip" {
    value = aws_launch_template.launch_template.id
}
