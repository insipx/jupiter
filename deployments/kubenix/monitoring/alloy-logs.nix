{ flake, ... }:
let
  ns = "monitoring";
  alloyImg = {
    label = "alloy-logs";
    image = "docker.io/grafana/alloy:v1.12.2";
    port = 12345;
  };
in
{
  serviceAccounts.alloy-logs = {
    metadata.namespace = ns;
    metadata.name = "alloy-logs";
  };

  clusterRoles.alloy-logs = {
    metadata.name = "alloy-logs";
    rules = [
      {
        apiGroups = [ "" ];
        resources = [ "pods" "nodes" ];
        verbs = [ "get" "list" "watch" ];
      }
    ];
  };

  clusterRoleBindings.alloy-logs = {
    metadata.name = "alloy-logs";
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io";
      kind = "ClusterRole";
      name = "alloy-logs";
    };
    subjects = [
      {
        kind = "ServiceAccount";
        name = "alloy-logs";
        namespace = ns;
      }
    ];
  };

  configMaps.alloy-logs-config = {
    metadata.namespace = ns;
    data."config.alloy" = builtins.readFile ./config-logs.alloy;
  };

  daemonSets."${alloyImg.label}" = {
    metadata.namespace = ns;
    metadata.labels.app = alloyImg.label;
    spec = {
      selector.matchLabels.app = alloyImg.label;
      template = {
        metadata.labels.app = alloyImg.label;
        # Roll the DaemonSet when config-logs.alloy changes (mounted via subPath,
        # which otherwise does not trigger a restart on ConfigMap update).
        metadata.annotations."checksum/config" =
          builtins.hashString "sha256" (builtins.readFile ./config-logs.alloy);
        spec = {
          serviceAccountName = "alloy-logs";
          # Run on control-plane nodes too, but do NOT blanket-tolerate everything:
          # we explicitly skip the disk/memory/pid-pressure and unschedulable taints
          # so a degraded node does not also get a root hostPath log shipper piled on.
          tolerations = [
            {
              key = "node-role.kubernetes.io/control-plane";
              operator = "Exists";
              effect = "NoSchedule";
            }
            {
              key = "node-role.kubernetes.io/master";
              operator = "Exists";
              effect = "NoSchedule";
            }
          ];
          containers."${alloyImg.label}" = {
            name = alloyImg.label;
            image = alloyImg.image;
            # Read root-owned /var/log/pods regardless of image USER default or PodSecurity.
            securityContext.runAsUser = 0;
            args = [
              "run"
              "/etc/alloy/config.alloy"
              "--server.http.listen-addr=0.0.0.0:${toString alloyImg.port}"
              "--storage.path=/var/lib/alloy/data"
            ];
            env = [
              {
                name = "NODE_NAME";
                valueFrom.fieldRef.fieldPath = "spec.nodeName";
              }
            ];
            volumeMounts = [
              {
                name = "config";
                mountPath = "/etc/alloy/config.alloy";
                subPath = "config.alloy";
              }
              {
                name = "varlogpods";
                mountPath = "/var/log/pods";
                readOnly = true;
              }
              {
                name = "data";
                mountPath = "/var/lib/alloy/data";
              }
            ];
            resources = {
              requests = {
                memory = "128Mi";
                cpu = "100m";
              };
              limits = {
                memory = "256Mi";
                cpu = "300m";
              };
            };
          };
          volumes = [
            {
              name = "config";
              configMap.name = "alloy-logs-config";
            }
            {
              name = "varlogpods";
              hostPath.path = "/var/log/pods";
            }
            {
              # Positions file persists per-node so tail resumes across restarts.
              name = "data";
              hostPath = {
                path = "/var/lib/alloy-logs";
                type = "DirectoryOrCreate";
              };
            }
          ];
        };
      };
    };
  };
}
