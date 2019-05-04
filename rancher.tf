data "helm_repository" "rancher-stable" {
  name = "rancher-stable"
  url  = "https://releases.rancher.com/server-charts/stable"
}

resource "helm_release" "rancher" {
  name       = "rancher"
  namespace  = "cattle-system"
  repository = "${data.helm_repository.rancher-stable.metadata.0.name}"
  chart      = "rancher-stable/rancher"

  set {
    name  = "hostname"
    value = "${var.rancher_host}.${var.cloudflare_zone}"
  }

  set {
    name  = "ingress.tls.source"
    value = "letsEncrypt"
  }

  set {
    name  = "letsEncrypt.email"
    value = "${var.letsencrypt_email}"
  }

  depends_on = ["helm_release.cert-manager"]
}
