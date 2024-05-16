machine:
  network:
    hostname: ${HOSTNAME}
    nameservers:
      - 1.1.1.1
      - 8.8.8.8
    interfaces:
      - addresses:
         - ${NODE_IP}/24
        deviceSelector:
          physical: true
        vip:
          ip: ${VIP}
  features:
    kubePrism:
      enabled: true
      port: 7445
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:reader
      allowedKubernetesNamespaces:
        - kube-system
  install:
    image: ${TALOS_IMAGE}
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
  inlineManifests:
    - name: controller
      contents: -|
        apiVersion: gateway.networking.k8s.io/v1beta1
        kind: GatewayClass
        metadata:
          name: cilium
        spec:
          controllerName: io.cilium/gateway-controller
    - name: cilium
      contents: ${CILIUM_MANIFEST}
