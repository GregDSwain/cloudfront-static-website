output "content_s3_bucket" {
  value = aws_s3_bucket.content_bucket.bucket
}

output "redirect_s3_bucket" {
  value = aws_s3_bucket.redirect_bucket.bucket
}

output "content_cloudfront_distro" {
    value = aws_cloudfront_distribution.content_cf_distro.id
}

output "redirect_cloudfront_distro" {
    value = aws_cloudfront_distribution.redirect_cf_distro.id
}

output "certificate" {
    value = aws_acm_certificate.cert.arn
}
