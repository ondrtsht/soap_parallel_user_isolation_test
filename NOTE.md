作成しました。**実際のSOAP APIへ接続して試験できるサンプル一式**です。

[SOAP並列ユーザー分離試験サンプル一式（ZIP）](sandbox:/mnt/data/soap_parallel_user_isolation_test_sample.zip)

### 含まれるもの

```text
soap_parallel_user_isolation_test/
├── README.md
├── DRY_RUN.md
├── config.env.example
│
├── bin/
│   ├── check_prerequisites.sh
│   ├── run_parallel_curl.sh
│   ├── run_stress.sh
│   └── verify_response.sh
│
├── requests/
│   ├── request_A.xml
│   └── request_B.xml
│
├── jmeter/
│   ├── soap_user_isolation.jmx
│   └── testdata.csv
│
└── results/
    ├── sample_response_A_OK.xml
    └── sample_response_B_MISMATCH.xml
```

### まず確認できること

実APIがなくても、

```bash
./bin/verify_response.sh \
  USER-A \
  TEST-A-000001 \
  results/sample_response_A_OK.xml
```

で、

```text
OK expectedUser=USER-A actualUser=USER-A ...
```

となります。

一方、意図的に別ユーザーの応答を入れたサンプルでは、

```bash
./bin/verify_response.sh \
  USER-B \
  TEST-B-000002 \
  results/sample_response_B_MISMATCH.xml
```

として、

```text
NG expectedUser=USER-B actualUser=USER-A ...
```

となることまで確認済みです。

つまり、**「HTTP 200だからOK」ではなく、要求ユーザー／Correlation Keyと応答電文を突き合わせてNGを検出するところまで実装済み**です。

### 実環境での最初の手順

```bash
unzip soap_parallel_user_isolation_test_sample.zip
cd soap_parallel_user_isolation_test

cp config.env.example config.env
vi config.env
```

対象Axis2のURLを、

```bash
SOAP_URL="http://対象サーバ:8080/axis2/services/実際のサービス名"
SOAP_ACTION="実際のSOAPAction"
```

に変更します。

その後、

```bash
./bin/run_parallel_curl.sh
```

で、

```text
USER-A ──┐
        ├── 同時curl → Axis2/Tomcat → Backend
USER-B ──┘
```

を実行します。

さらに、

```bash
./bin/run_stress.sh 100
```

なら、**USER-A/USER-Bを100回、各回で並列実行**します。

---

一点だけ重要です。今回のJMeter `.jmx` とSOAP XMLは、現時点では**実際のSOAP APIのWSDL／Request／Response構造をまだ見ていないため、`userId`、`requestKey`、XPath、SOAPAction、URLをサンプル値にしています**。

もし実際の **SOAP Request/Responseのサンプル電文（機密値をマスクしたもので可）またはWSDL** をいただければ、次はこの一式を対象APIに合わせて、**そのまま実行できるJMeter `.jmx` とbashスクリプトに具体化**できます。特に「どの項目をユーザー識別キーとして照合するか」を実電文から決めるのが重要です。
