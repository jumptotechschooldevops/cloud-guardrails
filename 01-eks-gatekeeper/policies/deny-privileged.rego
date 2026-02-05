package kubernetes.security

deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  container.securityContext.privileged == true
  msg := "Privileged containers are not allowed"
}

