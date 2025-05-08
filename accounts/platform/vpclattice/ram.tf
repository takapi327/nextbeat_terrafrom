data "aws_organizations_organization" "nextbeat" {}

data "aws_caller_identity" "self" {}

resource "aws_ram_resource_share" "vpclattice_share" {
  name = "VPCLatticeShare"
}

// TODO: aws_organizations_organizational_unitsを使用してOUのIdを取得できなかったためこのような構成にしている
resource "aws_ram_principal_association" "vpclattice_share" {
  principal          = "arn:aws:organizations::${ data.aws_organizations_organization.nextbeat.master_account_id }:ou/${ data.aws_organizations_organization.nextbeat.id }/${ var.organization_takapi327_ou_id }"
  resource_share_arn = aws_ram_resource_share.vpclattice_share.arn
}

resource "aws_ram_resource_association" "vpclattice_share" {
  resource_arn       = "arn:aws:vpc-lattice:${ var.region }:${ data.aws_caller_identity.self.account_id }:servicenetwork/${ aws_vpclattice_service_network.microservice_network.id }"
  resource_share_arn = aws_ram_resource_share.vpclattice_share.arn
}
