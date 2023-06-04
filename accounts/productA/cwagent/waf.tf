locals {
  waf_name       = "ProductA-CWAgent-WAF"
  ip_restriction = "IP-Restriction"
  rate_limit     = "RATE-LIMIT"
}

/**
 * WAF IPセット
 * @SEE https://docs.aws.amazon.com/ja_jp/waf/latest/developerguide/waf-ip-set-creating.html
 */
resource "aws_wafv2_ip_set" "ipv6_restriction" {
  name               = "IPV6-Restriction" // IPセットの名前
  scope              = "CLOUDFRONT"       // AWS CloudFront配信用か、地域のアプリケーション用かどうか。 CloudFrontで動作させるためには、AWSのプロバイダーでus-east-1を指定する必要がある
  provider           = aws.us-east-1      // リージョン
  ip_address_version = "IPV6"             // IPV4またはIPV6を指定
  addresses = [                           // CIDR（Classless Inter-Domain Routing）表記の1つまたは複数のIPアドレスまたはIPアドレスのブロックを指定する文字列の配列
    var.home_wifi.ipv6
  ]
}

resource "aws_wafv2_ip_set" "ipv4_restriction" {
  name               = "IPV4-Restriction"
  scope              = "CLOUDFRONT"
  provider           = aws.us-east-1
  ip_address_version = "IPV4"
  addresses = [
    var.home_wifi.ipv4
  ]
}

resource "aws_wafv2_web_acl" "cwagent_waf" {
  name        = local.waf_name             // WAFの名前
  description = "WAF for ProductA CWAgent" // WAFの説明
  scope       = "CLOUDFRONT"               // AWS CloudFront配信用か、地域のアプリケーション用かどうか。 CloudFrontで動作させるためには、AWSのプロバイダーでus-east-1を指定する必要がある
  provider    = aws.us-east-1              // リージョン

  // WebACLに含まれるルールのいずれにもマッチしなかった場合に実行するアクション。
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true           // CloudWatchにメトリクスを送信するかどうか
    metric_name                = local.waf_name // CloudWatchメトリック名
    sampled_requests_enabled   = true           // AWS WAFがルールにマッチしたWebリクエストのサンプリングを保存するかどうか
  }

  // 許可、ブロック、またはカウントしたいWebリクエストを特定するために使用するルール
  rule {
    name     = local.ip_restriction // ルール名
    priority = 0                    // 優先度

    // ルールのアクション
    action {
      block {}
    }

    // AWS WAFがWebリクエストがルールにマッチするかどうかを判断するために使用する
    statement {
      not_statement { // 条件から除外する
        statement {
          or_statement { // 複数条件の設定
            statement {
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.ipv6_restriction.arn
              }
            }
            statement {
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.ipv4_restriction.arn
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.ip_restriction
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList" // ボットやその他の脅威と一般的に関連するIPアドレスをブロックしたい場合に使用する
    priority = 1

    // マネージドアクションの上書き
    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet" // ウェブアプリケーションに一般的に適用されるルール OWASP Top 10などのOWASP出版物に記載されている高リスクで一般的に発生する脆弱性を含む、広範囲の脆弱性の悪用に対する保護を行う
    priority = 2

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet" // 無効であることがわかっているリクエストパターンや、脆弱性の悪用や発見に関連するリクエストパターンをブロックする
    priority = 3

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet" // SQLインジェクション攻撃など、SQLデータベースの悪用に関連するリクエストパターンをブロックする
    priority = 4

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = local.rate_limit
    priority = 5

    action {
      count {}
    }

    statement {
      rate_based_statement {       // 発信元IPアドレスごとにリクエストの割合を追跡し、その割合が5分間の時間帯に指定したリクエスト数の制限を超えた場合に、ルールのアクションをトリガーする
        limit              = 10000 // 1つの発信IPアドレスに対する5分間のリクエスト数の制限
        aggregate_key_type = "IP"  // リクエスト回数をどのように集計するか FORWARDED_IPまたはIP

        scope_down_statement {
          not_statement { // 条件から除外する
            statement {
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.ipv6_restriction.arn
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.rate_limit
      sampled_requests_enabled   = true
    }
  }
}
