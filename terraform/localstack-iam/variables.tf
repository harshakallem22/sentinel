variable "endpoint" {
  description = "LocalStack edge endpoint"
  type        = string
  default     = "http://localhost:4566"
}

variable "bucket_name" {
  description = "Bucket that stores load-test results"
  type        = string
  default     = "sentinel-results"
}

variable "results_prefix" {
  description = "The only key prefix the CI role may write to"
  type        = string
  default     = "loadtest/"
}
