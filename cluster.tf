provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_kubernetes_cluster" "do-k8s-cluster" {
  name    = "do-k8s-cluster"
  region  = "${var.do_region}"
  version = "${var.do_k8s_version}"

  node_pool {
    name       = "do-k8s-worker-pool"
    size       = "${var.do_worker_size}"
    node_count = "${var.do_worker_count}"
  }
}

provider "kubernetes" {
  host = "${digitalocean_kubernetes_cluster.do-k8s-cluster.endpoint}"

  client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.do-k8s-cluster.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(digitalocean_kubernetes_cluster.do-k8s-cluster.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.do-k8s-cluster.kube_config.0.cluster_ca_certificate)}"
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name      = "tiller"
  }
  role_ref {
    name      = "cluster-admin"
    kind      = "ClusterRole"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "kube-system"
    api_group = ""
  }
}

provider "helm" {
  install_tiller  = true
  service_account = "tiller"

  kubernetes {
    host = "${digitalocean_kubernetes_cluster.do-k8s-cluster.endpoint}"

    client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.do-k8s-cluster.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(digitalocean_kubernetes_cluster.do-k8s-cluster.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.do-k8s-cluster.kube_config.0.cluster_ca_certificate)}"
  }
}

resource "helm_release" "cert-manager" {
  name      = "cert-manager"
  namespace = "kube-system"
  chart     = "stable/cert-manager"
  version   = "v0.5.2"
}
