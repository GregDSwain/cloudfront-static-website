# CloudFront Static Website
## Description
Terraform code to deploy a CloudFront distribution in AWS to host a static website stored in S3.  
## Features
- Creates SSL/TLS certificate, site will be served as secure
- Redirects nonexistent subdomains of your site to your content
- Site may be served from root domain instead of www subdomain
- Optionally redirects other domains (and their subdomains) to your content
## Required
- AWS Account
- IAM User Access Key
- Hosted Zone for domain on AWS
> [!NOTE]
> If you register a domain in AWS Route 53, the default option should be to also create a Hosted Zone for it.
## Getting Started
1. Install Terraform  
https://developer.hashicorp.com/terraform/install
2. Make your AWS IAM User Access Key available in the environment  
    ```
    export AWS_ACCESS_KEY_ID=<access_key_value>
    export AWS_SECRET_ACCESS_KEY=<secret_key_value>
    ```
3. Initialize Terraform and deploy infrastructure
    ```
    terraform init
    terraform apply
    ```  
    You will be prompted to enter a value for the variable `content_root_domain_name`.  
> [!IMPORTANT]
> The value for `content_root_domain_name` ***MUST*** be a root domain name (e.g. `example.com`).  Your content will be served on its www subdomain (e.g. `www.example.com`).  This behavior may be changed, see Options below.

5. Check the web for example content  
    The `./html/index.html` file from this repo should be served on www subdomain of the root domain you provided.
> [!TIP]
> It will take several minutes for the content to be available after the deployment completes.  This is due to DNS record propagation.
## Next Steps
Update the website by changing the files in the S3 Bucket indicated by the `content_s3_bucket` output value that was displayed after the apply.  You may view the output values again with the command
```
terraform output
```
> [!WARNING]
> Changes made to files in the S3 Bucket will not be apparent until the cache in CloudFront cache expires.  You will want to invalidate the cache manually instead of waiting.  Refer to AWS documentation to perform this operation.
## Cleaning Up
You may destroy the infrastructure you deployed with this command
```
terraform destroy
```
You will be prompted to enter a value for the variable `content_root_domain_name` again.
> [!IMPORTANT]
> The value you give for `content_root_domain_name` should be ***exactly*** the same value you gave when you ran the `terraform apply` command earlier.
## Going Further
> [!CAUTION]
> It is possible that changing these variables could cause a S3 Bucket to be recreated.  This would destroy any files you have stored there.  Make sure your content is safely stored elsewhere before making changes.
Give values to following variables to change behavior:
- `serve_content_on_www_subdomain` - Set to `false` to serve your content from the root domain (e.g. `example.com`) instead of its www subdomain (e.g. `www.example.com`).  The redirect for the subdomain wildcard will still send traffic to the www subdomain to your content.
- `redirect_root_domain_names` - Provide a list of root domains to have their traffic and and their subdomains' traffic redirected to your content.
- `default_web_server_file` -  Modify to change the name of the file served as the default webpage.
> [!TIP]
> Create a `<name>.tfvars` file for these variable values and give its name on the command line (`terraform apply -var-file="<name>.tfvars"`) when creating infrastructure.  You may reuse this variable file when destroying your infrastructure later (`terraform destroy -var-file="<name>.tfvars"`).
## Where are the AWS Objects
AWS Services used by this code:
- S3 - file storage
- Certificate Manager - SSL/TLS certificate
- CloudFront - content distribution
- Route 53 - DNS records
## Details
The redirects used are 301 HTTP responses generated from a S3 bucket.  Using this method, in lieu of CNAME records in DNS, should help with SEO.  
Custom error pages for 4XX HTTP responses are being used.  You should give the 4XX.html files in the content bucket appropriate content so as to not confuse your users.
## Known Limitations
You must manage the website content in the S3 bucket.  This just deploys the infrastructure and some dummy webpages.  
There are no 5XX custom error pages.  AWS recommends a method of providing this functionality.  It has not been implemented.  
There is no provision here for renewing the certificate when it expires.