resource "kubernetes_namespace_v1" "helm_namespace" {
  metadata {
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }

    name = "metallb-system"
  }
}

resource "helm_release" "metal_lb" {
  name       	   = "metallb"
  repository 	   = "https://metallb.github.io/metallb"
  chart      	   = "metallb"

  namespace   	   = kubernetes_namespace_v1.helm_namespace.metadata.0.name
}


resource "kubernetes_manifest" "IPAddressPool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name = "first-pool"
      namespace = kubernetes_namespace_v1.helm_namespace.metadata.0.name
    }
    spec = {
      addresses : [
        "${cidrhost(var.subnet, var.ip_offset)}-${cidrhost(var.subnet, var.ip_offset + var.number_of_ips)}"
      ]
    }
  }
}

resource "kubernetes_manifest" "L2Advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name = "layer2"
      namespace = kubernetes_namespace_v1.helm_namespace.metadata.0.name
    }
    spec = {
      ipAddressPools: ["first-pool"]
    }
  }
}
