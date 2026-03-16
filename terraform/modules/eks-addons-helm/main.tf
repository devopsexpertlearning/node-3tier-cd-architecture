locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# Initialize required Helm repositories before installing charts
resource "null_resource" "helm_repos" {
  provisioner "local-exec" {
    command = join(" && ", [
      "helm repo add --force-update vmware-tanzu https://vmware-tanzu.github.io/helm-charts",
      "helm repo add --force-update metrics-server https://kubernetes-sigs.github.io/metrics-server",
      "helm repo add --force-update eks https://aws.github.io/eks-charts",
      "helm repo add --force-update open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts",
      "helm repo update"
    ])
  }
}

# Envoy Gateway
resource "helm_release" "envoy_gateway" {
  count = var.enable_envoy_gateway ? 1 : 0

  name             = "eg"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_chart_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  wait             = true

  values = var.envoy_gateway_custom_values != "" ? [var.envoy_gateway_custom_values] : []

  lifecycle {
    ignore_changes = [values]
  }

  depends_on = [null_resource.helm_repos]
}

# Metrics Server
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.metrics_server_chart_version
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
    # EKS Fargate fix: default port 10250 conflicts with the Fargate kubelet
    # because pod IP = node IP on Fargate. Use 4443 so the kube-apiserver
    # discovery check reaches metrics-server instead of the kubelet.
    containerPort = 4443
    args = [
      "--kubelet-insecure-tls",
      "--kubelet-preferred-address-types=InternalIP",
      "--secure-port=4443"
    ]
  })]

  lifecycle {
    ignore_changes = [values]
  }

  depends_on = [null_resource.helm_repos]
}

# Velero
resource "helm_release" "velero" {
  count = var.enable_velero ? 1 : 0

  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  version          = var.velero_chart_version
  namespace        = "velero"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    configuration = {
      backupStorageLocation = [{
        name     = "default"
        provider = "aws"
        bucket   = var.velero_backup_s3_bucket
        config   = { region = var.aws_region }
      }]
      volumeSnapshotLocation = [{
        name     = "default"
        provider = "aws"
        config   = { region = var.aws_region }
      }]
    }
    initContainers = [{
      name         = "velero-plugin-for-aws"
      image        = "velero/velero-plugin-for-aws:v1.9.0"
      volumeMounts = [{ mountPath = "/target", name = "plugins" }]
    }]
    serviceAccount = {
      server = {
        create = true
        name   = "velero"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.velero_iam_role_arn
        }
      }
    }
    schedules = var.enable_velero_schedule ? {
      daily-backup = {
        disabled = false
        schedule = "0 2 * * *"
        template = {
          ttl                     = "720h"
          includeClusterResources = true
          storageLocation         = "default"
          volumeSnapshotLocations = ["default"]
        }
      }
    } : {}
  })]

  lifecycle {
    ignore_changes = [values]
  }

  depends_on = [null_resource.helm_repos]
}

# AWS Load Balancer Controller
resource "helm_release" "alb_controller" {
  count = var.enable_alb_controller ? 1 : 0

  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.alb_controller_chart_version
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.aws_region
    vpcId       = var.vpc_id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.alb_controller_iam_role_arn
      }
    }
  })]

  lifecycle {
    ignore_changes = [values]
  }

  depends_on = [null_resource.helm_repos]
}

# RBAC — allow adot-collector ServiceAccount to discover pods/nodes/services
# Required by the Prometheus receiver's kubernetes_sd_configs (role: pod)
resource "kubernetes_cluster_role" "adot_collector" {
  count = var.enable_adot_collector ? 1 : 0

  metadata {
    name = "adot-collector"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "nodes/metrics", "services", "endpoints", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "adot_collector" {
  count = var.enable_adot_collector ? 1 : 0

  metadata {
    name = "adot-collector"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.adot_collector[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "adot-collector"
    namespace = "opentelemetry"
  }
}

# Fargate Built-in Logging (Fluent Bit → CloudWatch Logs)
resource "kubernetes_namespace" "aws_observability" {
  count = var.enable_fargate_logging ? 1 : 0

  metadata {
    name = "aws-observability"
    labels = {
      "aws-observability" = "enabled"
    }
  }
}

resource "kubernetes_config_map" "fargate_logging" {
  count = var.enable_fargate_logging ? 1 : 0

  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws_observability[0].metadata[0].name
  }

  data = {
    "flb_log_cw"   = "true"
    "output.conf"  = <<-EOT
      [OUTPUT]
          Name              cloudwatch_logs
          Match             *
          region            ${var.aws_region}
          log_group_name    /aws/eks/${var.cluster_name}/fargate
          log_stream_prefix fargate-
          auto_create_group true
          log_retention_days ${var.fargate_log_retention_days}
    EOT
    "parsers.conf" = <<-EOT
      [PARSER]
          Name        docker
          Format      json
          Time_Key    time
          Time_Format %Y-%m-%dT%H:%M:%S.%LZ
    EOT
    "filters.conf" = <<-EOT
      [FILTER]
          Name                kubernetes
          Match               kube.*
          Merge_Log           On
          Keep_Log            Off
          K8S-Logging.Parser  On
          K8S-Logging.Exclude Off
    EOT
  }
}

# ADOT Collector (AWS Distro for OpenTelemetry) — Metrics + Tracing
resource "helm_release" "adot_collector" {
  count = var.enable_adot_collector ? 1 : 0

  name             = "adot-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = var.adot_collector_chart_version
  namespace        = "opentelemetry"
  create_namespace = true
  wait             = true

  values = [yamlencode({
    mode         = "deployment"
    replicaCount = var.adot_collector_replicas
    image = {
      repository = "otel/opentelemetry-collector-contrib"
    }
    serviceAccount = {
      create = true
      name   = "adot-collector"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.adot_iam_role_arn
      }
    }
    config = {
      receivers = {
        otlp = {
          protocols = {
            grpc = { endpoint = "0.0.0.0:4317" }
            http = { endpoint = "0.0.0.0:4318" }
          }
        }
        prometheus = {
          config = {
            scrape_configs = [{
              job_name              = "kubernetes-pods"
              scrape_interval       = "30s"
              kubernetes_sd_configs = [{ role = "pod" }]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                  action        = "keep"
                  regex         = "true"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_port"]
                  action        = "replace"
                  target_label  = "__address__"
                  regex         = "(.+)"
                  replacement   = "$$1"
                }
              ]
            }]
          }
        }
      }
      processors = {
        batch = {
          timeout         = "30s"
          send_batch_size = 1000
        }
        memory_limiter = {
          limit_mib       = 400
          spike_limit_mib = 100
          check_interval  = "5s"
        }
      }
      exporters = {
        awsemf = {
          region                  = var.aws_region
          namespace               = "ContainerInsights"
          log_group_name          = "/aws/containerinsights/${var.cluster_name}/performance"
          dimension_rollup_option = "NoDimensionRollup"
        }
        awsxray = {
          region = var.aws_region
        }
      }
      service = {
        pipelines = {
          metrics = {
            receivers  = ["otlp", "prometheus"]
            processors = ["memory_limiter", "batch"]
            exporters  = ["awsemf"]
          }
          traces = {
            receivers  = ["otlp"]
            processors = ["memory_limiter", "batch"]
            exporters  = ["awsxray"]
          }
        }
      }
    }
  })]

  lifecycle {
    ignore_changes = [values]
  }

  depends_on = [null_resource.helm_repos]
}
