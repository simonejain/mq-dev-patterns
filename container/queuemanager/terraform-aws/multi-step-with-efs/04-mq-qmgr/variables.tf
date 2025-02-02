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

# The region used by the all .tf files
variable "region" {
  description = "The aws region to apply these services to"
  default     = "eu-west-2"
  type        = string
}

variable "mq_app_password" {
  description = "The App user password for MQ"
  type        = string
  sensitive   = true
}

variable "mq_admin_password" {
  description = "The Admin user password for MQ"
  type        = string
  sensitive   = true
}

variable "envvars" {
  type        = map(string)
  description = "variables to set in the environment of the container"
  default = {
    "LICENSE"      = "accept",
    "MQ_QMGR_NAME" = "QM1"
  }
}

# The container name needs to be consistent so that the
# ECS service can correctly configure the load balancer.
variable "mq_container_name" {
  description = "Container name"
  default     = "mq-container"
  type        = string
}

# The number of running containers 
variable "app_count" {
  type    = number
  default = 1
}

# The log group is paramertized as its usage needs to
# be consistent throughout the script. Otherwise the
# queuemanager image will fail to start, as it hits
# errors when trying to log.  
variable "log_group" {
  description = "CloudWatch log group"
  default     = "/devex/mq/terraform/efs"
  type        = string
}


# Additional vars to located pre-defined VPC and EFS

variable "vpc_id" {
  description = "The VPC to deploy these services to"
  type        = string
}

variable "efs_id" {
  description = "EFS that MQ will use for persistent storage"
  type        = string
}

variable "efs_access_point" {
  description = "EFS Access point"
  type        = string
}

# Suffix to add to uniquely identify created resources
variable "name_suffix" {
  description = "name suffix"
  type        = string
}