// generates radom string to append to a bucket name
// intended to ensure name is suitably (but not definitively) random
// created as a module mostly for DRY code, mostly
resource "random_string" "content_bucket_suffix" {
  length      = 6
  lower       = true
  numeric     = true
  upper       = false
  special     = false
  min_lower   = 2
  min_numeric = 2
}

output "result" {
  value = random_string.content_bucket_suffix.result
}
