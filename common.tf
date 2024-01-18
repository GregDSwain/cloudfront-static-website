
locals {
  content_domain_name = var.serve_content_on_www_subdomain ? "www.${var.content_root_domain_name}" : var.content_root_domain_name
  
  redirect_domain_names = distinct(
      concat(
        var.serve_content_on_www_subdomain ? [var.content_root_domain_name] : [],
        ["*.${var.content_root_domain_name}"],
        [for domain in var.redirect_root_domain_names : "${domain}"],
        [for domain in var.redirect_root_domain_names : "*.${domain}"]
      )
    )

  all_root_domain_names = distinct(
    concat(
        [var.content_root_domain_name],
        var.redirect_root_domain_names
    )
  )
  
  // these are the only 4XX responses AWS bucket will return
  // must use strings so we can iterate w/for_each
  html_4XX_errors = ["400", "403", "404", "405", "414", "416"]

  // alias record types, A for ipv4 and AAAA for ipv6
  alias_record_types = ["A", "AAAA"]
}


// fetch data about our existing dns zones
// these should be setup in route53 at time dns name is established, like before now
data "aws_route53_zone" "dns_zones" {
  for_each = toset(local.all_root_domain_names)

  name         = each.value
  private_zone = false
}
