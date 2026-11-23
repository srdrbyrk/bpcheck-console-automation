# Validation / Doğrulama

## English

Release validation date: **2026-11-23**.

### Environment and scope

- Windows PowerShell 5.1; SQL Server 2025, version **17.0.5045.3**.
- Windows Authentication with sysadmin.
- A named local instance was supplied explicitly. Successful connection to the
  literal default `localhost` was **not** tested: the validation server uses
  a named instance, not a local default instance.
- Successful SQL tests explicitly enabled the certificate exception for this
  test environment. Trusted-certificate production connectivity was not
  integration tested. Certificate validation remains enabled by default.
- Original pinned procedure was already installed for release validation;
  it was verified and not replaced.

### Observed SQL results

| Scenario | Result |
|---|---|
| English CMD; ordinary option defaults; one database selected | `CompletedWithFindings`, 94 result sets, 489 rows, 0 SQL error rows |
| Turkish CMD; same options and scope | `CompletedWithFindings`, 94 result sets, 489 rows, 0 SQL error rows |
| Lower-load default profile; empty DB scope = all eligible databases | `CompletedWithFindings`, 101 result sets, 1,359 rows, 0 SQL error rows, about 87 seconds |

These are observed test outputs, not fixed counts or performance guarantees.
The all-database test intentionally overrode target, certificate exception
and report location, and used explicit `-NonInteractive` authorization. It
did not enable performance or index scans.

Before and after testing, xp_cmdshell and OLE Automation were **0**;
show advanced options remained **1**. The wrapper did not change them.

### Automated cases

Final local suite: **16/16 passed**, including both live CMD integration
flows. The offline subset consists of 10 cases.

The included test runner checks:

- PowerShell syntax.
- Out-of-range sampling interval.
- Injection-shaped and integer-overflow database scopes.
- Contradictory index/performance options fail rather than pretending to scan.
- Enter-only defaults cancel before SQL access in both languages.
- Invalid interactive choices fail explicitly in both languages.
- Connection failure returns nonzero and records `Failed`/`Connection`.
- Opt-in EN/TR CMD tests execute SQL2025 with ordinary defaults, verify the
  pinned installed module, count HTML tables, check language/closure and
  record skipped checks.

Tests write local evidence under ignored `Test-Sonuclari`. Real server
configuration, diagnostic findings and raw output are not shipped.

### Known unsuccessful earlier runs

An earlier run failed reading msdb with OS error 21 (device not ready).
After restart, a different all-database run with extended performance and
index checks enabled failed with upstream statistics-sampling divide by zero
(8134). Neither is counted as a successful diagnostic run. A restart is not
proof that storage/integrity issues are resolved.

The release keeps the upstream SQL unchanged. Turning extended checks off
avoids that sampling path but does not fix the upstream expression.

Separate TR/EN packages were also checked for package-default language,
Enter-only cancellation and standalone rebuilding. Their live SQL tests must
run sequentially: a concurrent test reproduced an upstream global temporary
table collision (`##tmpdbsizes`). The failure was surfaced, not hidden.

### Not covered

Other SQL Server versions; remote connectivity; SQL Authentication;
restricted-permission accounts; SAMPLED/DETAILED index scans; comprehensive
production load testing; storage repair; fresh CHECKDB; all new SQL2025
features; initial-install lifecycle in this release's final test cycle.
An earlier package cycle exercised download, hash validation and first
installation, but this is not a substitute for testing your environment.

## Türkçe

Doğrulama tarihi: **23 Kasım 2026**.

- Windows PowerShell 5.1 ve SQL Server 2025 **17.0.5045.3** kullanıldı.
- Sysadmin yetkili Windows hesabıyla, açıkça verilen yerel named instance
  üzerinde test yapıldı. Başarılı `localhost` varsayılan instance bağlantısı
  test edilmedi.
- Gerçek SQL testlerinde test ortamına özel sertifika istisnası açıkça seçildi.
  Üretimde güvenilir sertifikayla bağlantı entegrasyon testi yapılmadı;
  aracın varsayılan sertifika doğrulaması açıktır.
- EN ve TR CMD akışlarında normal seçenek varsayılanlarıyla tek DB testi:
  her birinde **94 sonuç kümesi, 489 satır, 0 SQL hata satırı**.
- Veritabanı kapsamı boş, daha düşük yüklü varsayılan profilde:
  **101 sonuç kümesi, 1.359 satır, 0 SQL hata satırı**, yaklaşık **87 saniye**.
  Sunucu, sertifika istisnası ve rapor yolu test için açıkça verildi;
  `-NonInteractive` ile çalıştırma açıkça onaylandı.
- Sonuçlar `CompletedWithFindings`: yürütme tamamlandı, ancak inceleme gerektiren
  bulgular var. Sayılar ve süre başka çalışmalarda değişebilir.
- xp_cmdshell ve OLE Automation **0**, show advanced options **1** kaldı.
  Kurulu özgün prosedür doğrulandı; değiştirilmedi.

Son yerel test döngüsünde **16/16 test geçti**; buna iki dilde gerçek CMD-SQL
akışı dahildir. SQL tanılaması başlatmayan alt küme 10 testten oluşur.
Otomatik testler giriş doğrulamasını, iki dilde Enter ile güvenli iptali,
çelişkili seçeneklerin reddini, bağlantı hatasının doğru yansıtılmasını,
EN/TR gerçek CMD-SQL akışını ve HTML/özet bütünlüğünü kapsar.

Önceki OS error 21 ve restart sonrası genişletilmiş kontrollerdeki 8134
istatistik örnekleme hatası başarılı test sayılmadı. Restart, depolama veya
veritabanı bütünlüğünün düzeldiğini kanıtlamaz. Performans kontrollerini
kapatmak özgün hatalı sorguyu düzeltmez; o kontrol yolunu atlar.

Ayrı TR/EN paketlerinde varsayılan dil, Enter ile iptal ve bağımsız paketleme
de kontrol edildi. Gerçek SQL testleri sırayla çalıştırılmalıdır: eşzamanlı
denemede özgün global geçici tablo (`##tmpdbsizes`) çakışması görüldü.
Hata gizlenmeden raporlandı.

Uzak sunucu, SQL Authentication, düşük yetki, diğer SQL sürümleri,
SAMPLED/DETAILED taramalar, kapsamlı üretim yük testi, depolama onarımı, yeni
tam CHECKDB ve tüm SQL2025 özellikleri kapsam dışıdır. Bu sürümün son test
döngüsünde ilk kurulum tekrarlanmadı; önceki paket döngüsünde indirme/hash/ilk
kurulum denenmişti. Kendi ortamınıza özgü testlerin yerine geçmez.
