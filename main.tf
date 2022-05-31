# Get list of private subnets
data "aws_subnets" "private" {
  tags = {
    Tier = "Private"
  }
}

# Create DynamoDB
resource "aws_dynamodb_table" "users_table" {
  name             = "Users"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "UserId"
  range_key        = "Name"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "Name"
    type = "S"
  }

  # It is recommended to use replica instead of aws_dynamodb_global_table
  replica {
    region_name = "us-east-2"
  }
}


resource "aws_dynamodb_table_item" "add_user" {
  table_name = aws_dynamodb_table.users_table.name
  hash_key   = aws_dynamodb_table.users_table.hash_key
  range_key  = aws_dynamodb_table.users_table.range_key
  for_each = {
    item1 = {
      UserId = "123"
      Name   = "Bob"
    }
    item2 = {
      UserId = "456"
      Name   = "Ted"
    }
  }
  item = <<ITEM
  {
  "UserId":  { "S":"${each.value.UserId}" },
  "Name": { "S": "${each.value.Name}"}
}
ITEM
}

# Role for dax
resource "aws_iam_role" "dax" {
  name = "processing-service-role-dax"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "dax.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Create dax
resource "aws_dax_cluster" "user_dax" {
  cluster_name       = "user-dax"
  iam_role_arn       = aws_iam_role.dax.arn
  node_type          = "dax.t3.small"
  replication_factor = 1
}

# Dax parameter group
resource "aws_dax_parameter_group" "dax_pg" {
  name = "dax-parameter-group"

  parameters {
    name  = "query-ttl-millis"
    value = "5000000"
  }
}

# Dax subnet group
resource "aws_dax_subnet_group" "dax_subnet" {
  name       = "dax-subnets"
  subnet_ids = data.aws_subnets.private.ids
}

