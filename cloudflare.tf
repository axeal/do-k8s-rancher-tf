provider "cloudflare" {
  email = "${var.cloudflare_email}"
  token = "${var.cloudflare_token}"
}

resource "cloudflare_record" "rancher_hostname" {
  domain  = "${var.cloudflare_zone}"
  name    = "${var.rancher_host}"
  value   = "${kubernetes_service.nginx-ingress.load_balancer_ingress.0.ip}"
  type    = "A"
  proxied = true
}
