// set up out variables and locals
variable "content_root_domain_name" {
  type        = string
  description = "The root domain name (e.g. 'example.com' without a subdomain) from which main content will be served."
  nullable    = false
}

variable "serve_content_on_www_subdomain" {
  type        = bool
  description = "Boolean determines if content will be serverd from root domain or www subdomain.  Default is true = serve content from www subdomain (e.g. 'www.example.com').  Set to false to serve content from root domain (e.g. 'example.com')."
  default     = true
}

variable "redirect_root_domain_names" {
  type        = list(string)
  description = "List of other root domains that should redirect to your content.  A redirect for the root domain (e.g. 'example.com') and a wildcard for its subdomains (e.g. '*.example.com.) will both be created."
  default     = []
}

variable "default_web_server_file" {
  type        = string
  description = "Name of the default web page to be served when none is specified."
  default     = "index.html"
}
