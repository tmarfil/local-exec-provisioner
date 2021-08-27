# Terraform local-exec provisioner to check if web service is ready.

- The Terraform local-exec provisioner can be used to delay when Terraform marks a resource created until _after_ the resource has passed a health check.
- In this example, the health check is a user defined shell script **wait-for-endpoint.sh**.

## Test the example.

Clone this repo and change into the working directory.
```
git clone https://github.com/tmarfil/local-exec-provisioner.git
cd local-exec-provisioner
```
Terraform apply
```
terraform init
terraform plan
terraform apply
```
Terminal output
```
aws_instance.web: Creating...
aws_instance.web: Still creating... [10s elapsed]
aws_instance.web: Provisioning with 'local-exec'...
aws_instance.web (local-exec): Executing: ["/bin/sh" "-c" "./wait-for-endpoint.sh http://52.70.89.22 -t 300"]
aws_instance.web: Still creating... [20s elapsed]
aws_instance.web (local-exec): wait-for-endpoint.sh: waiting 300 seconds for http://52.70.89.22
aws_instance.web: Still creating... [30s elapsed]
aws_instance.web (local-exec): wait-for-endpoint.sh: http://52.70.89.22 is alive after 13 seconds
aws_instance.web: Creation complete after 33s [id=i-015ff25ee2df7ba9f]
```
- Terraform creates aws_instance "web" and computes the assigned public_ip attribute for aws_instance "web".
- local-exec provisioner is a part of the aws_instance "web" resource and runs the ./wait-for-endpoint.sh shell script against the public_ip attribute of aws_instance "web".
- **wait-for-endpoint.sh** either:
  - receives a successful http 200 response code, then Terraform marks the resource "created" or...
  - times out and Terraform fails

**Below is the relevant snippet from _main.tf._**

```
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.f5_management.id]
  tags = {
    Name = "marfil-test"
  }

  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /var/www && cd /var/www
    echo "App v${var.release}" >> index.html
    python3 -m http.server 80
  EOF

  lifecycle {
    create_before_destroy = true
  }
  provisioner "local-exec" {
    command = "./wait-for-endpoint.sh http://${self.public_ip} -t 300"
# Simulate a failed health check by commenting out the line above and uncommenting the line below:
#   command = "./wait-for-endpoint.sh http://too.much.fail.biz -t 15"
  }
}
```
To simulate a failed health check, run the wait-for-endpoint.sh script against a bogus url with a short timeout.

```
command = "./wait-for-endpoint.sh http://too.much.fail.biz -t 15"
```

## Citations

Based on an example from [Terraform in Action](https://www.manning.com/books/terraform-in-action).

Uses the [wait-for-endpoint.sh](https://github.com/cec/wait-for-endpoint/blob/master/wait-for-endpoint.sh) shell script.
