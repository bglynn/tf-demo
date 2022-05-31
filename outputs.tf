output "stream_arn" {
  value = aws_dynamodb_table.users_table.stream_arn
}
