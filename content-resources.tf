
locals {
  content_literal          = "content"
  content_bucket_origin_id = join("-", [local.content_literal, "bucket"])
}

module "content_bucket_name_suffix" {
  source = "./modules/bucket_name_suffix"
}

// create a "regular" bucket, doesn't have to be setup as static website
// named like descriptive prefix, dash, "main" part of domain name, dash, random string suffix
resource "aws_s3_bucket" "content_bucket" {
  bucket = join("-", [
    local.content_literal, 
    split(".", var.content_root_domain_name)[0], 
    module.content_bucket_name_suffix.result
  ])
}

resource "aws_s3_object" "content_index_html" {
  bucket       = aws_s3_bucket.content_bucket.id
  key          = var.default_web_server_file
  source       = "./html/${var.default_web_server_file}"
  content_type = "text/html"
}

resource "aws_s3_object" "content_error_htmls" {
  for_each = toset(local.html_4XX_errors)

  bucket       = aws_s3_bucket.content_bucket.id
  key          = "${each.value}.html"
  source       = "./html/error/${each.value}.html"
  content_type = "text/html"
}


// write iam policy that alllos cloudfront distribution to read/list bucket
data "aws_iam_policy_document" "content_bucket_policy_text" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.content_bucket.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.content_cf_distro.arn]
    }
  }

  // req'd to generate 404 when requested file not in bucket
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.content_bucket.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.content_cf_distro.arn]
    }
  }
}

// per documentation, Origin Access Control (OAC) recommended by AWS and supported by provider via this mechanism
resource "aws_cloudfront_origin_access_control" "content_bucket_origin_access_control" {
  name                              = local.content_bucket_origin_id
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}



// assign the policy to the bucket 
resource "aws_s3_bucket_policy" "content_bucket_policy" {
  bucket = aws_s3_bucket.content_bucket.id
  policy = data.aws_iam_policy_document.content_bucket_policy_text.json
}



// create the coludfront distribution
resource "aws_cloudfront_distribution" "content_cf_distro" {
  aliases             = [local.content_domain_name]
  default_root_object = var.default_web_server_file
  enabled             = true
  price_class         = "PriceClass_100" // North America & Europe only (cheaper?)
  is_ipv6_enabled     = true  // requires AAAA dns records to work

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    // a Managed Cache Policy defined by AWS, here "CachingOptimized"
    // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = local.content_bucket_origin_id
    viewer_protocol_policy = "redirect-to-https"
  }

  origin {
    domain_name              = aws_s3_bucket.content_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.content_bucket_origin_access_control.id
    origin_id                = local.content_bucket_origin_id
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  dynamic "custom_error_response" {
    for_each = local.html_4XX_errors

     content {
      error_code         = custom_error_response.value
      response_code      = custom_error_response.value
      response_page_path = "/${custom_error_response.value}.html"
    }
  }

  depends_on = [aws_acm_certificate_validation.cert_validation]
}

// create A and AAAA dns records to resolve our domain names to the cloudfront distribution
resource "aws_route53_record" "content_dns_record" {
  for_each = toset(local.alias_record_types)

  name    = local.content_domain_name
  type    = each.value
  zone_id = data.aws_route53_zone.dns_zones[var.content_root_domain_name].zone_id
  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.content_cf_distro.domain_name
    zone_id                = aws_cloudfront_distribution.content_cf_distro.hosted_zone_id
  }
}
