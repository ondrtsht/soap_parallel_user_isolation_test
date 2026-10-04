# SOAP API User-Isolation Parallel Test Sample

## 目的

異なるユーザーが同一SOAP APIへ並列アクセスした際に、要求したユーザーとは別ユーザーのデータが応答電文へ混入しないことを自動検証するサンプルです。

このサンプルでは、要求と応答の双方に以下の2つのキーを想定しています。

- `userId`: ユーザー識別子
- `requestKey`: 1リクエスト単位の一意キー

期待結果:

    request userId=A, requestKey=A-000001
        -> response userId=A, responseKey=A-000001 : OK

異常例:

    request userId=A, requestKey=A-000001
        -> response userId=B, responseKey=B-000002 : NG

## ディレクトリ

    bin/
      run_parallel_curl.sh       2ユーザーを並列実行
      verify_response.sh         XML応答を照合
      run_stress.sh              大量反復

    requests/
      request_A.xml               USER-A用SOAP
      request_B.xml               USER-B用SOAP

    jmeter/
      soap_user_isolation.jmx     JMeterテスト計画
      testdata.csv               ユーザー/期待値

    results/
      (実行時に生成)

    config.env.example            接続先などの設定

## 最初に行う設定

    cp config.env.example config.env
    vi config.env

最低限、以下を対象環境に合わせて変更してください。

    SOAP_URL
    SOAP_ACTION

また、実際のSOAP APIのXML構造が異なる場合は、

    requests/request_A.xml
    requests/request_B.xml
    jmeter/soap_user_isolation.jmx

のSOAP bodyおよびXPathを対象APIに合わせて変更してください。

## bash/curl版

    chmod +x bin/*.sh
    ./bin/run_parallel_curl.sh

結果は results/ に保存されます。

単独で再判定する場合:

    ./bin/verify_response.sh \
      USER-A \
      TEST-A-000001 \
      results/response_A.xml

## JMeter版

GUI:

    jmeter -t jmeter/soap_user_isolation.jmx

CLI:

    jmeter -n \
      -t jmeter/soap_user_isolation.jmx \
      -l results/jmeter.jtl \
      -j results/jmeter.log

JMeterテストでは2スレッドをSynchronizing Timerで同期させ、USER-A/USER-Bを並列送信します。

## 注意

これはAPI固有のWSDLを見て作ったものではないため、XML namespace、SOAPAction、ユーザーキーのXPathはサンプル値です。
本番/顧客環境へ投入する前に、対象APIの実際のRequest/Responseに合わせて置換してください。

HTTP 200だけではOK判定しません。
応答電文中のユーザー識別情報とCorrelation Keyを照合してOK/NGを決定します。
