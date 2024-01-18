
locals {
  redirect_literal          = "redirect"
}

module "redirect_bucket_name_suffix" {
  source = "./modules/bucket_name_suffix"
}

// create a bucket
// named like descriptive prefix, dash, "main" part of domain name, dash, random string suffix
// to perform a rediect function, the bucket must be configured to be static web site with 
// the "aws_s3_bucket_website_configuration" resource next
resource "aws_s3_bucket" "redirect_bucket" {
  bucket = join("-", [
    local.redirect_literal, 
    split(".", var.content_root_domain_name)[0],
    module.redirect_bucket_name_suffix.result
  ])
}

// configure bucket to act as static website, BUT redirect all requests
resource "aws_s3_bucket_website_configuration" "redirect_bucket_website_config" {
  bucket = aws_s3_bucket.redirect_bucket.id

  redirect_all_requests_to {
    host_name = local.content_domain_name
    protocol  = "https" // per AWS recommendation
  }
}


// create the coludfront distribution
resource "aws_cloudfront_distribution" "redirect_cf_distro" {
  aliases         = local.redirect_domain_names
  enabled         = true
  price_class     = "PriceClass_100" // North America & Europe only (cheaper?)
  is_ipv6_enabled = true // requires AAAA dns records to work

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    // a Managed Cache Policy defined by AWS, here "CachingDisabled"
    // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = aws_s3_bucket_website_configuration.redirect_bucket_website_config.id 
    viewer_protocol_policy = "redirect-to-https"
  }

  origin {
    // there's a bug in terraform?
    //   value for 'domain_name' MUST be the 'website_endpoint' for the s3 redirect
    //     using 'domain_name = aws_s3_bucket.redirect_bucket.website_endpoint'
    //       yields warning for deprecation
    //     using 'domain_name = aws_s3_bucket_website_configuration.redirect_bucket_website_config.website_endpoint'
    //       yields error 'InvalidArgument: The parameter Origin DomainName does not refer to a valid S3 bucket.'
    // some consensus on internet about avoiding bug via this implementation
    domain_name = aws_s3_bucket_website_configuration.redirect_bucket_website_config.website_endpoint
    origin_id   = aws_s3_bucket_website_configuration.redirect_bucket_website_config.id 

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    minimum_protocol_version = "TLSv1.2_2021" // min protocol recommended by AWS as of Jan 2024
    ssl_support_method       = "sni-only"
  }

  depends_on = [aws_acm_certificate_validation.cert_validation]
}

// for each alias type (A and AAAA) and for each redirect domain,
// create DNS record to resolve redirect domain name to redirect cloudfront distribution
resource "aws_route53_record" "redirect_dns_record" {
  for_each = {
    for thing in setproduct(local.alias_record_types, local.redirect_domain_names) :
      "${thing[0]}${thing[1]}" => {
        type   = thing[0]
        domain = thing[1]
      }
  } 
  
  name    = each.value.domain
  type    = each.value.type
  zone_id = data.aws_route53_zone.dns_zones[trimprefix(each.value.domain, "*.")].zone_id
  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.redirect_cf_distro.domain_name
    zone_id                = aws_cloudfront_distribution.redirect_cf_distro.hosted_zone_id
  }
}
