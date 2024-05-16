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
  features:
    kubePrism:
      enabled: true
      port: 7445
  install:
    image: ${TALOS_IMAGE}