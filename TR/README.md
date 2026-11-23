# BPCheck Konsol Otomasyonu


Microsoft SQL Server BPCheck'i çift tıklamayla başlatmak, parametrelerini
konsoldan almak ve sonuçlarını yerel HTML, metin ve JSON raporlarına kaydetmek
için hazırlanmış Windows çalıştırıcısıdır. SSMS, sqlcmd veya ek PowerShell
modülü gerektirmez.

**Bağımsız bir topluluk çalıştırıcısıdır; Microsoft ürünü veya resmi destek
aracı değildir.** Sabitlenmiş özgün BPCheck prosedürünü çalıştırır; Microsoft'un
bütün önerilerini SQL Server 2025 için güncellemez.

## Üretim ortamında çalıştırmadan önce

> Tanılama, sıfır etki veya kesin salt okunurluk anlamına gelmez.
> Değişiklik onayı alın; depolama sağlığını kontrol edin, uygun zaman aralığı
> seçin ve dar veritabanı kapsamıyla başlayın. Varsayılanlar daha düşük
> yüklüdür; risksiz değildir. Hata veren sunucuda tekrar tekrar çalıştırmayın.

| Risk | Beklenen etki ve önlem |
|---|---|
| CPU, I/O, bellek ve tempdb | Genişletilmiş performans kontrolleri kapalıyken bile metadata/DMV sorguları, geçici nesneler ve veritabanları arası kontroller kaynak tüketir. |
| Geniş kapsam | `DatabaseIds` boşsa yalnızca mevcut veritabanı değil, **tüm uygun veritabanları** değerlendirilir. Dar kapsamda da instance ve bazı sistem veritabanı kontrolleri çalışır. |
| Süre ve blocking | Metadata kilitleri ve iş yükü etkileşimleri olabilir. Index taramaları ve ek kontroller yükü artırır. Önce dar kapsam seçin; ayrı bağlantıdan izleyin. |
| İlk kurulum | `msdb.dbo.usp_bpcheck` oluşturulur. Etkileşimli kullanımda ayrıca açık kurulum onayı gerekir; komut satırında `-Install` aynı yetkilendirmedir. Mevcut prosedürün üzerine yazılmaz. |
| Yüksek yetki | Tam kapsam için yüksek SQL yetkileri gerekir; eksik yetki kontrol atlanmasına veya hataya neden olabilir. Sırf uyarıyı kaldırmak için sysadmin vermeyin. CMD'yi yönetici açmak SQL sysadmin yetkisi vermez. |
| Hassas çıktı | Veritabanı adları, yapılandırma, dosya yolları, sorgu/modül metni ve işletim bilgileri rapora girebilir. Kısıtlı erişimli klasör kullanın. Araç sizin yerinize güvenli ACL veya anonimleştirme uygulamaz. |
| Şifreleme ve kimlik doğrulama | Şifreleme ve sunucu sertifikası doğrulaması açıktır. Üretimde doğrulamayı kapatmak yerine sertifika güven/ad sorununu çözün. |
| Eski öneriler / kaynak hataları | Özgün sorgular bazı veri veya metadata durumlarında hata verebilir. Hatalı rapor kısmidir; tamamlanma sağlık veya uyumluluk sertifikası değildir. |

Çalıştırıcı `allow_xpcmdshell`, `diskfrag`, `bpool_consumer`, `spn_check`,
`gen_scripts` ve `logdetail` parametrelerini daima `0` gönderir. xp_cmdshell
ve OLE Automation açmaz; bulguları otomatik düzeltmez. Bazı OS, disk, SPN ve
derin kontroller bu nedenle atlanır. Otomatik index oluşturma/silme/rebuild,
SQL restart, veritabanı onarımı veya zamanlanmış görev oluşturma yapmaz.

## Gereksinimler

- Windows ve Windows PowerShell **5.1** (`powershell.exe`).
- SQL bağlantısı, uygun SQL yetkileri ve `msdb` erişimi.
- Kaynak SQL önbelleği için yazılabilir paket klasörü; raporlar için yeterli
  alanı ve uygun erişim kısıtları olan yazılabilir hedef.
- Kaynak önbellekte yoksa `raw.githubusercontent.com` HTTPS erişimi.
  İnternetsiz kullanımda sabit sürümün SQL dosyasını önceden PS1 yanına koyun.
- Kurumsal script imzalama/çalıştırma politikasına uyum. Başlatıcı politikayı
  değiştirmez veya atlatmaz. İndirdiğiniz betikleri onaylamadan inceleyin.
- Bağlantı adıyla eşleşen güvenilir SQL sertifikası. Yalnızca güvenilir test
  ortamı için bilinçli sertifika istisnası seçilebilir.

**Doğrulanan ortam:** SQL Server 2025, 17.0.5045.3; sysadmin yetkili Windows
Authentication. Diğer sürümler, uzak sunucu, SQL Authentication ve kısıtlı
yetkili kullanım için entegrasyon testi yapılmamıştır.
[Test kapsamına](VALIDATION.md) bakın.

## Hızlı başlangıç

1. Dağıtım ZIP'ini indirin ve klasöre çıkarın.
2. TR paketinde **`BPCheck-Baslat.cmd`** dosyasına çift tıklayın.
   Ayrı EN paketinde **`BPCheck-Start.cmd`** bulunur.
3. `SQLHOST\INSTANCE` veya `tcp:SQLHOST,1433` gibi hedef girin.
   Boş bırakırsanız **`localhost`**, yani yerel varsayılan instance kullanılır.
   Named instance otomatik bulunmaz; farklı hedefe otomatik geçilmez.
4. Diğer varsayılanları kabul edin veya dar veritabanı ID kapsamı seçin.
5. Gösterilen hedefi, kapsamı ve seçenekleri inceleyin. Çalıştırmak için **E**
   veya **Y** yazın. Sadece Enter basılması **SQL bağlantısı açılmadan iptal**
   eder.
6. Prosedür yoksa ilk kuruluma ayrıca açık onay verin.
7. Yazdırılan rapor klasöründeki `Rapor.html` ve `Ozet.json` dosyalarını inceleyin.

**Hiç giriş yapmadan başarılı sonuç garantisi yoktur.** Varsayılanlar isteğe
bağlı ayar yükünü kaldırır; bağlantı/yetki gereksinimlerini veya açık onayı
kaldırmaz. Bütün sorularda Enter basılması iptal eder. Sertifika doğrulamasını
otomatik kapatma, izinsiz kurulum, daha zayıf kimlik doğrulamaya geçiş, başka
sunucu deneme veya otomatik onarım yapılmaz.

### Varsayılanlar

| Ayar | Varsayılan |
|---|---|
| Hedef | `localhost` — varsayılan instance |
| Motor dili | Paketin dili (`TR` veya `EN`); `-Language` ile değiştirilebilir |
| Kimlik doğrulama | `Windows`, işlemi çalıştıran hesap |
| Örnekleme aralığı | `60` saniye; **toplam süre değil** |
| Genişletilmiş performans kontrolleri | Kapalı (`H` / `N`) |
| Index fragmentation | Kapalı (`H` / `N`) |
| Index tarama modu | `LIMITED`; fragmentation açıkken anlamlı |
| Veritabanı kapsamı | Tüm uygun veritabanları; instance kontrolleri de uygulanır |
| Komut zaman aşımı | `1800` saniye; toplam iş süresi sınırı değil |
| TLS / sertifika doğrulaması | İkisi de açık |
| Rapor hedefi | Script yanındaki `Raporlar`; her çalışma için benzersiz alt klasör |
| Çalıştırma / ilk kurulum onayı | Hayır; açık onay gerekir |

### Parametreler

Parametreler isteğe bağlıdır; ön koşullar ve açık çalıştırma onayı devam eder.
Etkileşimli mod, verilen parametreleri sorulardaki varsayılan olarak gösterir.

| Parametre | Değer ve anlam |
|---|---|
| `-Server` | `localhost`, `HOST\INSTANCE` veya `tcp:HOST,PORT`. Tek başına port numarası sunucu adresi değildir. |
| `-Language` | `EN` veya `TR`; konsol ve çalıştırıcı rapor başlıkları. Özgün SQL içeriği ve sürücü hataları çevrilmez. |
| `-Authentication` | `Windows` veya `SQL`. SQL modunda kullanıcı adı ve gizli parola etkileşimli sorulur. Komut satırında parola kabul edilmez. |
| `-Username` | İsteğe bağlı SQL kullanıcı adı; parola değildir. |
| `-Duration` | `10..255` tam sayı; ölçümler arası örnekleme aralığı. |
| `-Performance` | Büyük/küçük harf duyarsız `E/H` veya `Y/N`. Özgün genişletilmiş performans/index/istatistik kontrollerini yönetir; varsayılan kapalıdır. |
| `-IndexFragmentation` | `E/H` veya `Y/N`. Ek index analizi; özgün kodda kontroller iç içe olabildiğinden `Performance` da açılmalıdır. |
| `-IndexScanMode` | `LIMITED`, `SAMPLED`, `DETAILED`. Ayrıntı arttıkça tarama maliyeti önemli ölçüde artabilir. |
| `-DatabaseIds` | Tırnak içinde virgüllü pozitif tam sayı listesi: `"5,7"`. Veritabanı adı değildir. ID mevcut, erişilebilir ve ONLINE olmalıdır. Boşsa tüm uygun veritabanları. |
| `-OutputDirectory` | Rapor kök klasörü; yeterli alan ve erişim kısıtlarını sağlayın. |
| `-CommandTimeout` | `30..86400` saniye; SQL komutları içindir, toplam süre taahhüdü değildir. İptal/temizlik ek süre alabilir. |
| `-TrustServerCertificate` | Sunucu sertifikası doğrulamasını açıkça atlar; şifreleme devam eder. Üretim varsayılanı değildir. |
| `-Install` | İlk kurulumun açık onayıdır; mevcut prosedürü değiştirmez. |
| `-NonInteractive` | Sorular olmadan çalıştırmayı açıkça yetkilendirir. Yalnızca Windows Authentication. `-Install` ile birlikte yalnızca kurulum onaylıysa kullanın. |

Yetkili bağlantıda veritabanı ID'lerini görmek için:

```sql
SELECT database_id, name, state_desc
FROM sys.databases
ORDER BY database_id;
```

### Örnekler

Türkçe, dar kapsam, daha düşük yüklü varsayılanlar ve açık onaylar:

```powershell
.\BPCheck-Calistir.ps1 -Language TR -Server "SQLHOST\INSTANCE" -DatabaseIds "5,7"
```

İsteğe bağlı performans ve LIMITED index kontrolleri:

```powershell
.\BPCheck-Calistir.ps1 -Language TR -Server "SQLHOST\INSTANCE" `
    -DatabaseIds "5" -Performance E -IndexFragmentation E -Duration 30
```

Güvenilir sertifika ile onaylı ilk kurulum ve sorusuz çalıştırma:

```powershell
powershell.exe -NoProfile -File ".\BPCheck-Calistir.ps1" `
    -Language TR -Server "SQLHOST\INSTANCE" -DatabaseIds "5" `
    -OutputDirectory "D:\RestrictedReports\BPCheck" -Install -NonInteractive
```

Task Scheduler için onaylı Windows görev hesabıyla PS1'i `-NonInteractive`
parametresiyle çağırın; ilk kurulumdan sonra `-Install` gerekmez. CMD sonunda
beklediğinden zamanlayıcıda CMD kullanmayın. Script, kaynak SQL ve rapor
klasörlerini izinsiz değişikliğe karşı koruyun. Araç çakışan çalışmaları
engellemez; zamanlayıcıda üst üste çalışmamayı yapılandırın.
İki dil paketini aynı SQL instance'ına eşzamanlı çalıştırmayın.
Özgün BPCheck global geçici tablolar (örneğin `##tmpdbsizes`) kullandığından
çakışan oturumlar "object already exists" hatasıyla durabilir.

## Sonuçlarda ne göreceksiniz, ne öğreneceksiniz?

Bölümler SQL sürümüne, yetkilere, özgün kontrolün uygulanabilirliğine ve
parametrelere göre değişir. Bir bölümün olmaması/atlanması **başarılı kontrol**
anlamına gelmez.

| Alan | Bilgi ve yorumlama |
|---|---|
| Instance / OS / HA | Sürüm, uptime, yapılandırma, görünür HA ve envanter; bağlam sağlar, tam destek değerlendirmesi değildir. |
| CPU / bellek | MAXDOP/NUMA gözlemleri, bellek ayarları ve kullanım sinyalleri; iş yükü ve güncel üretici önerileriyle birlikte incelenir. |
| Veritabanı / tempdb / dosyalar | Compatibility ve DB seçenekleri, büyüme ayarları, VLF ve tempdb gözlemleri; takip gerektiren konuları gösterir. xp_cmdshell kapalıyken bazı volume kontrolleri yapılamaz. |
| Bakım / bütünlük geçmişi | Uygun olduğunda backup, CHECKDB geçmişi, suspect pages, alert ve errorlog gözlemleri. **Yeni bir tam DBCC CHECKDB veya restore testi değildir.** |
| Performans — isteğe bağlı | Wait/latch ve sayaç örnekleri, I/O, blocking ve plan cache sinyalleri. Anlık/son restart'tan beri biriken ipuçlarıdır; tek başına kök neden kanıtı değildir. |
| Index / istatistik — isteğe bağlı | Eksik/benzer/kullanılmayan index ve istatistik gözlemleri; ayrıca fragmentation taraması. Değişiklikten önce iş yükü, uptime, index örtüşmesi ve yazma maliyeti değerlendirilir. |
| İsimlendirme / güvenlik / izleme | Uygulanabilir özgün kurallar ve izleme/güvenlik gözlemleri; kapsamlı güvenlik denetimi değildir. |

Araç otomatik üretim düzeltme planı, iş etkisi puanı, bütün SQL2025 özellikleri
için inceleme veya her kategorinin sonuç döndüreceği garantisi vermez.

## Raporlar ve çıkış kodları

Rapor aşamasına ulaşan her çalışmada `BPCheck_<tarih-saat>_<benzersiz-id>`
klasörü oluşturulur:

| Dosya | İçerik |
|---|---|
| `Rapor.html` | Tüm tablolar, bulgu vurguları, özet ve SQL mesajları. Hücreler HTML-encode edilir. |
| `Sonuclar.txt` | Sonuç kümelerine ayrılmış tab değerleri; hücre içi tab/satır sonları escape edilir. |
| `Mesajlar.log` | SQL mesajları ve exception ayrıntıları. |
| `Ozet.json` | Durum, hata aşaması, parametreler, süreler, sonuç sayıları, atlanan mesajlar ve kaynak doğrulaması. Makine tarafından okunan alan adları İngilizce ve sabittir. |

| Durum / kod | Anlam |
|---|---|
| `Completed` / `0` | Çalıştırma tamamlandı; sağlık sertifikası değildir. |
| `CompletedWithFindings` / `0` | Çalıştırma tamamlandı, metinsel bulgu/uyarı var; inceleyin. |
| `Failed` / `1` | Bağlantı, yetki, kaynak, SQL, çıktı veya özgün sorgu hatası; rapor kısmidir. Parametre bağlama hataları da rapor oluşturulmadan nonzero döner. |
| `Cancelled` / `2` | Etkileşimli çalıştırma onayı verilmedi; SQL bağlantısı ve rapor klasörü oluşturulmadı. |

`FindingRows`, `WARNING/ERROR/FAIL` metin eşleşmesidir; önem derecelendirmesi
değildir. `SqlErrorRows=0`, SQL hatası olmadığı anlamına gelmez; hiç satır
okunamadan hata alınabilir. Önce **Status + Error + Stage** alanlarını
inceleyin. `SkippedMessages`, `skipped`/`bypassed` içeren mesajları sayar;
kapatılan tüm kontrollerin eksiksiz envanteri değildir.

## Sorun giderme ve bilinen sınırlar

- **Sertifika hatası:** doğru ad ve güven zincirine sahip sertifika kullanın;
  transport güvenliğini sessizce düşürmeyin.
- **OS error 21 / ciddi I/O hatası:** tanılama tekrarlarını durdurun.
  SQL ERRORLOG, Windows ve depolama kayıtlarını inceleyin. Tek başına SQL
  restart, depolamanın veya veritabanı bütünlüğünün düzeldiğini kanıtlamaz.
  Depolama stabil olduktan sonra DBA yönetiminde bütünlük/geri dönüş planı
  uygulayın. Körlemesine `REPAIR_ALLOW_DATA_LOSS` kullanmayın.
- **Statistics sampling / sıfıra bölme (8134):** sabitlenmiş özgün kodun belirli
  bir veritabanında ürettiği hata gözlendi. Örnekleme ifadesi sıfır koruması
  olmadan satır sayısına bölüyor. Çalıştırıcı hatayı gizlemez, istatistikleri
  değiştirmez ve Microsoft prosedürünü yamalamaz. Daraltılmış tanılama için
  `-Performance H` kullanın veya incelenmiş bir upstream düzeltmesini
  değerlendirin. Kontrolü atlamak, hatanın nedenini düzeltmek değildir.
- **Mevcut prosedür farklı:** üzerine yazmadan durur. Modül metni farklı olan
  ALTER/CREATE OR ALTER sürümleri de buna dahildir. DBA özgün metni ve
  kurulu tanımı karşılaştırmalıdır; eşleşme sağlamak için üretim prosedürünü
  otomatik silmeyin.
- **Timeout / kısmi rapor:** kapsamı daraltın, pahalı kontrolleri kapatın ve
  kaynak kullanımını izleyin. Yalnızca zaman aşımını sürekli artırmayın.

## Kaynak, yayınlama ve lisans

Özgün proje: [microsoft/tigertoolbox BPCheck](https://github.com/microsoft/tigertoolbox/tree/master/BPCheck).
Çalıştırıcı yalnızca sabit SQL kaynağını HTTPS ile indirir; SQL verisi veya
rapor yüklemez. İlk indirme için GitHub'a bağlantı kurulur.

- Commit: `0b0c137ff2809c086e6a9ae65e9e69ceca13e475`
- SHA256: `357B11A121B3AE0DAEAB2125CE8AAE8C2F49FEC3561A6A974779C9862C302B72`

Kurulum/çalıştırma öncesi kaynak hash'i doğrulanır; kurulu modül, satır sonları
normalize edilerek sabit tanımla karşılaştırılır. SQL mantığı değiştirilmez.
Bu kontrol, yetkili bir kişinin/eşzamanlı işlemin sonradan değişiklik yapmasını
engelleyen bir güvenlik sınırı değildir.

Çalıştırıcı kodu [MIT lisanslıdır](LICENSE). Microsoft BPCheck ayrı bir üçüncü
taraf çalışmasıdır; [bildirime](THIRD-PARTY-NOTICES.txt) bakın.

**Bu çalışma klasörünü olduğu gibi GitHub'a göndermeyin:** yerel raporlar ve
test kanıtları içerir. Temiz, izin listeli dağıtım oluşturun:

```powershell
.\Build-Release.ps1
```

`dist\BPCheck-Console-Automation-TR.zip` ve
`dist\BPCheck-Console-Automation-EN.zip` ayrı üretilir. Her pakette kendi
başlatıcısı, kendi dilinde ana README ve varsayılan dil ayarı bulunur.
Ortak motor, testler, paketleme scripti, lisans, doğrulama/üçüncü taraf
bildirimleri ve ignore kuralları da dahildir. Ortak teknik bildirim ve
testlerde İngilizce/Türkçe metin bulunabilir. Tek dilli paket yalnızca kendi
ZIP'ini yeniden oluşturur. SQL kaynağı,
ham raporlar, yerel test sonuçları ve parolalar dahil edilmez. ZIP'i **yeni
klasöre çıkarın**, içeriğini inceleyip GitHub deposunu orada başlatın.
`.gitignore` ek korumadır; staged dosya incelemesinin yerine geçmez.
Araç GitHub'a otomatik yayın yapmaz.

## Test

Gerçek SQL tanılaması başlatmadan:

```powershell
.\Test-Paket.ps1
```

Açıkça seçilmiş SQL2025 entegrasyon testi; sabit prosedür kurulu olmalıdır:

```powershell
.\Test-Paket.ps1 -RunSqlTest -Server ".\SQL2025" -DatabaseId 51
```

Örnek sunucu ve ID'yi onaylı test ortamınıza göre değiştirin. Gerçek testler
tanılama sorguları çalıştırır ve test ortamı için sertifika istisnası
kullanır. Prosedür kurmaz veya değiştirmez.
