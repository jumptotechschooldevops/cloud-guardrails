package kubernetes.security

deny[msg] {
  input.kind == "Pod"
  volume := input.spec.volumes[_]
  volume.hostPath
  msg := "hostPath volumes are not allowed"
}

