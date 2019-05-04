# Using kubernetes/ingress-nginx
# https://github.com/helm/charts/tree/master/stable/nginx-ingress
# https://github.com/kubernetes/ingress-nginx/releases

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
    name      = "nginx-config-controller"
    namespace = "nginx-ingress"
  }
}

resource "kubernetes_cluster_role" "nginx-ingress" {
    metadata {
        name = "nginx-ingress"
    }

    rule {
        api_groups = [""]
        resources  = ["services", "endpoints"]
        verbs      = ["get", "list", "watch"]
    }
    rule {
        api_groups = [""]
        resources  = ["secrets"]
        verbs      = ["get", "list", "watch"]
    }
    rule {
        api_groups = [""]
        resources  = ["configmaps"]
        verbs      = ["get", "list", "watch", "update", "create"]
    }
    rule {
        api_groups = [""]
        resources  = ["pods"]
        verbs      = ["list"]
    }
    rule {
        api_groups = [""]
        resources  = ["events"]
        verbs      = ["create", "patch"]
    }
    rule {
        api_groups = ["extensions"]
        resources  = ["ingresses"]
        verbs      = ["get", "list", "watch"]
    }
    rule {
        api_groups = ["extensions"]
        resources  = ["ingresses/status"]
        verbs      = ["update"]
    }
}

resource "kubernetes_cluster_role_binding" "nginx-ingress" {
  metadata {
    name      = "nginx-ingress"
  }
  role_ref {
    name      = "nginx-ingress"
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "nginx-ingress"
    namespace = "nginx-ingress"
    api_group = ""
  }
}

# Can remove manual mounting of service account token once the following is merged:
# https://github.com/terraform-providers/terraform-provider-kubernetes/pull/261
resource "kubernetes_deployment" "nginx-ingress-controller" {
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "nginx-ingress"
  }

  spec {
    replicas = 1
    progress_deadline_seconds = 60

    selector {
      match_labels {
        app = "nginx-ingress-controller"
      }
    }

    template {
      metadata {
        labels {
          app = "nginx-ingress-controller"
        }
      }

      spec {
        service_account_name = "nginx-ingress"
        container {
          image = "quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.22.0"
          name  = "nginx-ingress-controller"

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

          volume_mount {
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            name = "${kubernetes_service_account.nginx-ingress.default_secret_name}"
            read_only = true
          }

          args = ["/nginx-ingress-controller", "--default-backend-service=nginx-ingress/nginx-ingress-default-backend", "--election-id=ingress-controller-leader", "--ingress-class=nginx", "--configmap=nginx-ingress/nginx-ingress-controller"]

          security_context {
            capabilities {
              add = ["NET_BIND_SERVICE"]
              drop = ["ALL"]
            }
            run_as_user = "33"
          }

          liveness_probe {
            failure_threshold = 3
            http_get {
              path = "/healthz"
              port = "10254"
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds = 10
            success_threshold = 1
            timeout_seconds = 1
          }

          readiness_probe {
            failure_threshold = 3
            http_get {
              path = "/healthz"
              port = "10254"
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds = 10
            success_threshold = 1
            timeout_seconds = 1
          }

        }
        volume {
          name = "${kubernetes_service_account.nginx-ingress.default_secret_name}"
          secret {
            secret_name = "${kubernetes_service_account.nginx-ingress.default_secret_name}"
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "nginx-ingress-default-backend" {
  metadata {
    name      = "nginx-ingress-default-backend"
    namespace = "nginx-ingress"
  }

  spec {
    replicas = 1
    progress_deadline_seconds = 60

    selector {
      match_labels {
        app = "nginx-ingress-default-backend"
      }
    }

    template {
      metadata {
        labels {
          app = "nginx-ingress-default-backend"
        }
      }

      spec {
        container {
          image = "k8s.gcr.io/defaultbackend:1.4"
          name  = "nginx-ingress-default-backend"

          port {
            name           = "http"
            container_port = "8080"
          }

          liveness_probe {
            failure_threshold = 3
            http_get {
              path = "/healthz"
              port = "8080"
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds = 10
            success_threshold = 1
            timeout_seconds = 5
          }
        }

        termination_grace_period_seconds = 60
      }
    }
  }
}

resource "kubernetes_service" "nginx-ingress-controller" {
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "nginx-ingress"
  }

  spec {
    type = "LoadBalancer"

    selector {
      app = "nginx-ingress-controller"
    }

    port {
      name        = "http"
      port        = "80"
      target_port = "80"
    }

    port {
      name        = "https"
      port        = "443"
      target_port = "443"
    }
  }
}

resource "kubernetes_service" "nginx-ingress-default-backend" {
  metadata {
    name      = "nginx-ingress-default-backend"
    namespace = "nginx-ingress"
  }

  spec {
    type = "ClusterIP"

    selector {
      app = "nginx-ingress-default-backend"
    }

    port {
       name        = "http"
       port        = "80"
       target_port = "http"
    }
  }
}
