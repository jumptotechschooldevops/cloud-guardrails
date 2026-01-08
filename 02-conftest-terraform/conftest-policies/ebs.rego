package main

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "aws_ebs_volume"
  not rc.change.after.encrypted
  msg := sprintf("EBS volume %v must be encrypted", [rc.address])
}
