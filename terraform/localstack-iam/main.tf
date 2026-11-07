provider "aws" {
  region = "us-east-1"
  # LocalStack accepts any non-empty keys; these are not real AWS credentials
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    iam = var.endpoint
    s3  = var.endpoint
    sts = var.endpoint
  }

  default_tags {
    tags = {
      Owner     = "harshakallem22"
      Project   = "sentinel"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "results" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "results" {
  bucket                  = aws_s3_bucket.results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "ci_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "ci_results_writer" {
  name                 = "sentinel-ci-results-writer"
  description          = "CI uploads load-test summaries; nothing else"
  assume_role_policy   = data.aws_iam_policy_document.ci_trust.json
  max_session_duration = 3600
}

# PutObject only: CI never needs to read, list or delete results
data "aws_iam_policy_document" "ci_results_writer" {
  statement {
    sid       = "WriteLoadTestResultsOnly"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.results.arn}/${var.results_prefix}*"]
  }
}

resource "aws_iam_role_policy" "ci_results_writer" {
  name   = "write-loadtest-results"
  role   = aws_iam_role.ci_results_writer.id
  policy = data.aws_iam_policy_document.ci_results_writer.json
}
