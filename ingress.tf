resource "kubernetes_namespace" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "kubernetes_service_account" "nginx-ingress" {
  metadata {
    name      = "nginx-ingress"
    namespace = "nginx-ingress"
  }
}

resource "kubernetes_config_map" "nginx-config" {
  metadata {
    name      = "nginx-config"
    namespace = "nginx-ingress"
  }
}

resource "kubernetes_secret" "default-server-secret" {
  metadata {
    name      = "default-server-secret"
    namespace = "nginx-ingress"
  }

  data {
    "tls.crt" = "${var.default_server_cert}"
    "tls.key" = "${var.default_server_key}"
  }

  type = "Opaque"
}

#Once Terraform k8s provider released with ClusterRole support create new role for nginx-ingress
#https://github.com/terraform-providers/terraform-provider-kubernetes/pull/229
#https://github.com/nginxinc/kubernetes-ingress/blob/master/deployments/rbac/rbac.yaml

resource "kubernetes_cluster_role_binding" "nginx-ingress" {
  metadata {
    name      = "nginx-ingress"
  }
  role_ref {
    name      = "cluster-admin"
    kind      = "ClusterRole"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "nginx-ingress"
    namespace = "nginx-ingress"
    api_group = ""
  }
}

resource "kubernetes_deployment" "nginx-ingress" {
  metadata {
    name      = "nginx-ingress"
    namespace = "nginx-ingress"
  }

  spec {
    replicas = 1

    selector {
      match_labels {
        app = "nginx-ingress"
      }
    }

    template {
      metadata {
        labels {
          app = "nginx-ingress"
        }
      }

      spec {
        service_account_name = "nginx-ingress"
        container {
          image = "nginx/nginx-ingress:1.4.3"
          name  = "nginx-ingress"

          port {
            name           = "http"
            container_port = "80"
          }

          port {
            name           = "https"
            container_port = "443"
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          args = ["-nginx-configmaps=$(POD_NAMESPACE)/nginx-config", "-default-server-tls-secret=$(POD_NAMESPACE)/default-server-secret"]
        }
      }
    }
  }
}