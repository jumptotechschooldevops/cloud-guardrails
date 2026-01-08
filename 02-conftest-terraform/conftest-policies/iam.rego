package main

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "aws_iam_user"
  count(rc.change.after.tags) == 0
  msg := sprintf("IAM user %v must have tags", [rc.address])
}
