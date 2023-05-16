variable "region" {
  description = "AWS region"
  default     = "ap-northeast-1"
}

// Terraform CloudのWorkspaceに設定されている変数を参照する。
// TODO: Terraform Cloudの変数を使用するためにはExecution Modeをリモートにする必要がある。
// 一旦識別子を隠蔽したいためコマンドライン上で渡すようにしている
variable "organization_takapi327_ou_id" {
  description = "ID of OU managed by Organization"
  type        = string
}
