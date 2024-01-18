
resource "aws_acm_certificate" "cert" {
  domain_name               = local.content_domain_name
  subject_alternative_names = local.redirect_domain_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "route53_cert_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
    // when serving content on a root domain
    //   this list looks like ["*.example.com", "example.com", "*.example.org", "example.org"]
    // when serving content on www subdomain
    //   this list looks like ["www.example.com", "*.example.com", "example.com", "*.example.org", "example.org"]
    // 
    // we can skip the wildcard domains, they mimic exactly the root domain
    // we have to pick up the extra www domain when it is included in the list
    if (!startswith(dvo.domain_name, "*.")) || (dvo.domain_name == local.content_domain_name)
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  // get the root domain from the dvo.domain_name
  //    "www.example.com"          (split on ".")    
  //    ["www", "example", "com"]  (reverse) 
  //    ["com", "example", "www"]  (slice)
  //    ["com", "example"]         (reverse)
  //    ["example", "com"]         (join w/".")
  //    "example.com"
  zone_id  = data.aws_route53_zone.dns_zones[join(".",reverse(slice(reverse(split(".",each.key)),0,2)))].zone_id
}


resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.route53_cert_validation_records : record.fqdn]
}
