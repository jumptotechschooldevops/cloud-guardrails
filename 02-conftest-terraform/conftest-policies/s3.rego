package main

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "aws_s3_bucket"
  not sse_configured(rc)
  msg := sprintf("S3 bucket %v must enable SSE encryption", [rc.address])
}

sse_configured(rc) if {
  some i
  some j
  rc.change.after.server_side_encryption_configuration[i].rule[j].apply_server_side_encryption_by_default[0].sse_algorithm
}
