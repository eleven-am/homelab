machine:
  network:
    nameservers:
      - 1.1.1.1
      - 8.8.8.8
  features:
    kubePrism:
      enabled: true
      port: 7445
  install:
    image: ${MACHINE_IMAGE}
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
  inlineManifests:
    - name: cilium
      contents: |
            ${CILIUM_MANIFEST}
