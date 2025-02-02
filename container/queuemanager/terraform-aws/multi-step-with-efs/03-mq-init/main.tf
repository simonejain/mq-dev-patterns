#
# * Copyright 2023, 2024 IBM Corp.
# *
# * Licensed under the Apache License, Version 2.0 (the 'License');
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# * http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.

# This AssumeRole policy is needed to allow logging. 
# If Logging to CloudWatch isn't needed, then this AssumeRole policy can be removed.
# Without it you will get the following exception
# ClientException: Fargate requires task definition to have execution role ARN to support log driver awslogs.

#
# data blocks
#

data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# This script needs to be able to access the AWS AZs
data "aws_availability_zones" "available_zones" {
  state = "available"
}


# Task execution role and policy for AssumeRole to enable logging.
resource "aws_iam_role" "ecs_init_task_execution_role" {
  name               = "ecs-init-staging-execution-role-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_init_task_execution_role" {
  role       = aws_iam_role.ecs_init_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_task_definition" "mq_task" {
  family                   = "mq-dev"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_init_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048

  container_definitions = templatefile("${path.module}/mq-container-json.tftpl", {
    MQ_CONTAINER_NAME = var.mq_container_name,
    LOG_GROUP_NAME    = "${var.log_group}/${var.name_suffix}",
    REGION            = var.region,
    ENVVARS           = var.envvars
  })

  volume {
    name = "efs-volume"
    efs_volume_configuration {
      file_system_id     = data.aws_efs_file_system.mq.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = data.aws_efs_access_point.mq.id
      }
    }
  }

}

# Queue Manager security group. 
# Ingress rules are defined separately.
resource "aws_security_group" "mq_init_task_secuity_group" {
  name   = "mq-init-task-security-group"
  vpc_id = data.aws_vpc.mq_vpc.id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create the cloudwatch log group. 
# The log group name used by the ecs task definition must match this name.
resource "aws_cloudwatch_log_group" "mqlogs" {
  name = "${var.log_group}/${var.name_suffix}"
  # skip_destroy = true 
  # retention_in_days = 3
}


# Create the ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "mq-cluster-${var.name_suffix}"
}

# Once all the above pre-reqs are in place the ECS
# one of task can be started.
data "aws_ecs_task_execution" "mq-efs_init-task" {
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mq_task.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

   network_configuration {
     security_groups = [aws_security_group.mq_init_task_secuity_group.id]
     subnets         = data.aws_subnets.private.ids
     assign_public_ip = false
   }

  depends_on = [aws_iam_role_policy_attachment.ecs_init_task_execution_role]
}


