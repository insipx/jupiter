{ config
, lib
, pkgs
, kubenix
, ...
}:
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];

  submodules.imports = [
    ../lib/namespaced.nix
  ];

  submodules.instances.rbd-hdd-csi-nix = {
    submodule = "namespaced";

    args.kubernetes = {
      helm.releases = {
        rbd-csi = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://ceph.github.io/csi-charts";
            chart = "ceph-csi-rbd";
            version = "3.16.1";
            sha256 = "sha256-jsYqhYKoWjaGzPott9aCrBGPNprllPOSu5Dmlnsg7Kk=";
          };

          namespace = "rbd-hdd-csi-nix";

          values = {
            csiConfig = [{
              clusterID = "REDACTED";
              monitors = [
                "10.238.2.64:6789"
                "10.238.2.65:6789"
                "10.238.2.66:6789"
                "10.238.2.67:6789"
                "10.238.2.80:6789"
              ];
              # rdb = { };
              # readAffinity = { };
            }];
            secret = {
              create = true;
              userID = "kubernetes";
              userKey = "ref+sops://kubenix/rbd-hdd-csi/secrets.yaml#stringData/userKey";
            };
            storageClass = {
              create = true;
              name = "rbd-hdd-csi";
              clusterID = "REDACTED";
              pool = "kubernetes";
              fsType = "ext4";
              reclaimPolicy = "Delete";
              allowVolumeExpansion = true;
            };
          };
        };
      };

      resources = {
        persistentVolumeClaims.rbd-hdd-test-pvc.spec = {
          accessModes = [ "ReadWriteMany" ];
          storageClassName = "rbd-hdd-csi";
          resources.requests.storage = "1Gi";
          volumeMode = "Block";
        };

        pods.ceph-test-pod.spec = {
          restartPolicy = "Always";
          volumes = [{
            name = "rbd-block-dev";
            persistentVolumeClaim.claimName = "rbd-hdd-test-pvc";
          }];
          containers = [{
            name = "ceph-test-container";
            image = "registry.k8s.io/e2e-test-images/agnhost:2.39";

            volumeDevices = [{
              devicePath = "/dev/rbdblock";
              name = "rbd-block-dev";
            }];
          }];
        };
      };
    };
  };
}
