locals {
  origin_id = "productA"
}

resource aws_cloudfront_distribution product_a_cloudfront {

  comment = "ProductAアカウント用のCloudFront" // CloudFrontの説明

  origin {
    /** CloudFrontに紐づけるDNS */
    domain_name = aws_alb.product_a_alb.dns_name
    origin_id   = local.origin_id // オリジンの一意の識別子

    custom_origin_config {
      http_port                = 80  // カスタムオリジンが受け付けるHTTPのポート
      https_port               = 443 // カスタムオリジンが受け付けるHTTPSのポート
      origin_keepalive_timeout = 5 // CloudFrontがオリジンにリクエストを転送した後、レスポンスを待機する時間
      origin_protocol_policy   = "http-only" // オリジンに適用するプロトコルの種類 https-onlyにする場合オリジンに設定するドメイン用に証明書を取得する必要がある
      origin_read_timeout      = 30 // CloudFrontがオリジンから応答のパケットを受信した後、次のパケットを受信するまで待機する時間
      origin_ssl_protocols     = ["TLSv1", "TLSv1.1", "TLSv1.2"] // オリジンとHTTPSで通信する際にCloudFrontに使用させたいSSL/TLSプロトコル TLS 1.0 ～ 1.2 はたいていの機器で標準実装されているため許可を行う
    }

    /** CloudFrontに設定するヘッダー */
    custom_header {
      name  = "X-From-Restriction-Cloudfront"
      value = var.cloudfront_custom_header
    }
  }

  enabled         = true // ユーザーからのコンテンツ要求を受け付けることができるかどうか
  is_ipv6_enabled = true // IPv6を有効にするかどうか
  web_acl_id      = aws_wafv2_web_acl.product_a_waf.arn // 紐付けるWAF ACL

  /** デフォルトのキャッシュ動作設定 */
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"] // アクセスを許可するメソッド
    cached_methods         = ["GET", "HEAD"] // 指定したHTTPメソッドを使用したリクエストに対するレスポンスをキャッシュするかどうか
    target_origin_id       = local.origin_id // オリジンの一意の識別子
    viewer_protocol_policy = "redirect-to-https" // ユーザーがアクセスできるプロトコルを指定 redirect-to-httpsだとHTTPをHTTPSにリダイレクトさせる

    cache_policy_id          = aws_cloudfront_cache_policy.cloudfront_cache_policy.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.cloudfront_origin_request_policy.id
  }

  /**
   * アクセスを制限したい地域の設定 noneは制限しない
   * 制限する場合は、ホワイトリストとブラックリストを作成し、ISOのコードを使用し制限する
   * @SEE https://www.iso.org/iso-3166-country-codes.html
   */
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  /**
   * CloudFrontを配置する場所。PriceClass_100, PriceClass_200, PriceClass_Allから選択
   * @SEE https://docs.aws.amazon.com/ja_jp/AmazonCloudFront/latest/DeveloperGuide/PriceClass.html
   */
  price_class = "PriceClass_All"

  /**
   * SSL証明書の設定
   * CloudFrontは、デフォルトのドメイン名 (xxxxxx.cloudfront.net など) をディストリビューションに割り当てる。
   * このドメイン名を使用する場合は、デフォルトのSSL/TLS証明書を使用できる。
   * ディストリビューションで別のドメイン名を使用したい場合は、使用したいドメイン名に関連する証明書を設定する必要がある。
   * (AWS Certificate Managerを使用して証明書を発行する)
   */
  viewer_certificate {
    cloudfront_default_certificate = true // デフォルトのSSL/TLS証明書を使用するかどうか
  }

  tags = {
    Name: "Staging"
  }
}

resource aws_cloudfront_cache_policy cloudfront_cache_policy {
  name    = "ProductA-CloudfrontCachePolicy"
  comment = "デフォルトのキャッシュ設定"

  default_ttl = 10 // CloudFrontが別のリクエストを転送するまでの、オブジェクトがCloudFrontのキャッシュにあるデフォルトの時間
  min_ttl     = 10 // オブジェクトが更新されたかどうかをCloudFrontがオリジンに問い合わせるまでに、CloudFrontのキャッシュにオブジェクトを残しておく最小時間
  max_ttl     = 10 // CloudFrontが、オブジェクトが更新されたかどうかを判断するためにオリジンに別のリクエストを転送するまでの、CloudFrontのキャッシュ内にあるオブジェクトの最大時間

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Host", "Origin"] // HTTPヘッダーをキャッシュキーに含めるか
      }
    }

    cookies_config {
      cookie_behavior = "all" // クッキーをキャッシュキーに含めるか
    }

    query_strings_config {
      query_string_behavior = "none" // クエリ文字列をキャッシュキーに含めるか
    }
  }
}

resource aws_cloudfront_origin_request_policy cloudfront_origin_request_policy {
  name    = "ProductA-CloudfrontOriginRequestPolicy"
  comment = "デフォルトのオリジンリクエスト設定"

  // キャッシュキーには使わないが、オリジンサーバーに送信したい値を記載
  headers_config {
    header_behavior = "allViewer" // ヘッダーをオリジンリクエストに含めるか
  }

  cookies_config {
    cookie_behavior = "all" // クッキーをオリジンリクエストに含めるか
  }

  query_strings_config {
    query_string_behavior = "all" // クエリ文字列をオリジンリクエストに含めるか
  }
}
