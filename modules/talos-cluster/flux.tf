resource "null_resource" "wait_for_cluster" {
  count = var.enable_flux && var.control_plane_count > 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for cluster to be healthy..."
      export TALOSCONFIG="${var.output_directory}/talosconfig"

      for i in $(seq 1 30); do
        if talosctl --nodes ${local.control_plane_ips[0]} health --wait-timeout 30s 2>/dev/null; then
          echo "Cluster is healthy!"
          exit 0
        fi
        echo "Attempt $i/30: Cluster not ready yet, waiting..."
        sleep 10
      done

      echo "Cluster health check failed after 30 attempts"
      exit 1
    EOT
  }

  depends_on = [
    talos_machine_bootstrap.this,
    local_file.talosconfig,
  ]
}

resource "null_resource" "envoy_gateway" {
  count = var.control_plane_count > 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.output_directory}/kubeconfig"

      echo "Installing Envoy Gateway..."
      helm repo add envoy-gateway https://charts.gateway.envoyproxy.io || true
      helm repo update
      helm upgrade --install envoy-gateway envoy-gateway/gateway-helm \
        --namespace envoy-gateway-system --create-namespace \
        --version v1.6.1 \
        --wait --timeout 5m

      echo "Envoy Gateway installed successfully!"
    EOT
  }

  depends_on = [
    null_resource.wait_for_cluster,
    local_file.kubeconfig,
  ]
}

resource "null_resource" "sops_secret" {
  count = var.enable_flux && var.sops_age_key != "" && var.control_plane_count > 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.output_directory}/kubeconfig"

      echo "Creating flux-system namespace..."
      kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

      echo "Creating SOPS age key secret..."
      kubectl -n flux-system create secret generic sops-age \
        --from-literal=keys.agekey="${var.sops_age_key}" \
        --dry-run=client -o yaml | kubectl apply -f -

      echo "SOPS secret created successfully!"
    EOT
  }

  depends_on = [
    null_resource.wait_for_cluster,
    local_file.kubeconfig,
  ]
}

resource "null_resource" "flux_bootstrap" {
  count = var.enable_flux && var.github_token != "" && var.control_plane_count > 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.output_directory}/kubeconfig"
      export GITHUB_TOKEN="${var.github_token}"

      echo "Bootstrapping FluxCD..."
      flux bootstrap github \
        --owner="${var.github_username}" \
        --repository="${var.github_repository}" \
        --branch=main \
        --path="clusters/${var.cluster_name}" \
        --personal \
        --token-auth \
        --decryption-provider=sops \
        --decryption-secret=sops-age

      echo "FluxCD bootstrapped successfully!"
    EOT
  }

  depends_on = [
    null_resource.sops_secret,
    null_resource.envoy_gateway,
    local_file.kubeconfig,
  ]
}

resource "null_resource" "nvidia_runtime_class" {
  count = var.enable_nvidia_gpu && var.control_plane_count > 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.output_directory}/kubeconfig"

      echo "Creating NVIDIA RuntimeClass..."
      cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
EOF

      echo "NVIDIA RuntimeClass created successfully!"
    EOT
  }

  depends_on = [
    null_resource.wait_for_cluster,
    local_file.kubeconfig,
  ]
}
