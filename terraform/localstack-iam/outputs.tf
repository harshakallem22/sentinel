output "bucket" {
  value = aws_s3_bucket.results.bucket
}

output "ci_role_arn" {
  value = aws_iam_role.ci_results_writer.arn
}
