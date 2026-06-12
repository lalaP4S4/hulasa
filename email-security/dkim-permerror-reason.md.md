Bismillâhirrahmânirrahîm.

Hamd-i bî-pâyân âlemlerin Rabbi olan Allah Teâlâ’ya; salât ü selâm-ı bî-nihâye Enbiyâlar Serveri Efendimiz Hazret-i Muhammed’e, O'nun âl ve ashâbının cümlesine olsun.

Tenzih ve takdis ederiz ki, Senin bize tâlim buyurduğundan gayrı hiçbir ilmimiz yoktur; muhakkak ki Alîm and Hakîm olan ancak Sensin. Kezâlik, Senin bize ihsan ve tefhim buyurduğundan başka hiçbir fehmimiz ve idrakimiz yoktur; şüphesiz Cevâd ve Kerîm olan ancak Sensin.

Emmâ ba'd;

# 📑 DKIM Permerror Hatasının Genel Sebepleri ve Çözüm Yolları

> **Mebâdi-i Aşere (Hulasa-i Kelâm):**
> 
> - **Had (Tanım):** DKIM (DomainKeys Identified Mail) doğrulama sürecinde, kriptografik imzanın kalıcı olarak geçersiz sayılmasına yol açan `permerror` (Permanent Error) durumunun yapısal anatomisidir.
>     
> - **Gâye (Amaç):** E-posta ağ geçitleri (SEG) ve posta sunucuları (MTA) arasındaki imza kırılmalarını engellemek, alan adı itibarını korumak ve sahteciliği (spoofing) proaktif olarak önlemek.
>     
> - **Semere (Fayda):** Kurumsal e-postaların spam filtrelerine takılmadan hedefe ulaşması, DMARC politikalarının sıhhatle işletilmesi ve güvenli e-posta akış mimarisi.
>     

## 🏛️ 1. Dîbâce (Executive Summary & Tehdit Profillemesi)

E-posta güvenlik mimarilerinde DKIM, mesajın iletim esnasında bütünlüğünün bozulmadığını ve kaynağının doğruluğunu garanti altına alan asimetrik bir kriptografi katmanıdır. Alıcı sunucu, gelen e-postanın üst bilgisindeki (`header`) imza değerini, gönderici alan adının DNS kayıtlarındaki public key ile çözer.

Eğer bu süreçte imza doğrulaması kalıcı olarak başarısız olursa, alıcı MTA **DKIM Permerror** kaydı üretir. Bu hata geçici bir ağ kesintisinden (`temperror`) farklı olarak; ya verinin yolda tahrif edildiğini ya da mimari bir yapılandırma hatasını işaret eder. Bu makale, kurumsal SEG, milter ve akış mimarilerinde `permerror` hatasına sebebiyet veren anomalileri ve çözüm metodolojilerini inceler.

- **İlgili Katman:** Email Security (MTA, Secure Email Gateway)
    
- **Risk Derecesi:** Yüksek (E-Posta Teslimat ve İtibar Kaybı)
    
- **Referanslar / Standartlar:** RFC 6376 (DKIM), MITRE ATT&CK T1585.002
    

## 🛠️ 2. Usul ve Tatbikat (Anatomi ve Kök Nedenler)

### A. İmza Sonrası İçerik Müdahaleleri

MTA veya SEG tarafından kriptografik imza basıldıktan sonra, e-posta gövdesinde (`body`) veya kritik başlıklarında yapılacak en ufak bir değişiklik `permerror` ile sonuçlanır.

1. **Footer / Disclaimer Injection:** Kurumsal imza veya yasal uyarı metinlerinin e-postanın en altına merkezi ağ geçitleri tarafından sonradan eklenmesi.
    
2. **Subject Tagging:** Antivirüs veya antispam sistemlerinin, mail başlığına `[SPAM]` veya `[EXTERNAL]` gibi etiketler enjekte etmesi.
    
3. **MTA / Gateway Modifikasyonları:** Aradaki aktarım sunucularının mail gövdesini veya MIME yapısını yeniden kodlaması.
    

> [!CAUTION]
> 
> **Mimari Altın Kural:** E-posta üzerindeki tüm içerik manipülasyonları, etiketlemeler ve imza eklemeleri **DKIM imzalama motorundan önce** tamamlanmalıdır. DKIM, e-postanın çıkış kapısındaki en son mühür olmalıdır.

### B. Satır Sonu (Newline) ve Canonicalization İlişkisi

E-postalar platformlar arası iletilirken satır sonu karakterleri değişikliğe uğrayabilir:

- **Windows (CRLF):** `\r\n`
    
- **Unix/Linux (LF):** `\n`
    

DKIM imzalama esnasında bu farkların tolere edilebilmesi için **Canonicalization** algoritması kullanılır:

- **Simple:** Boşluklara ve satır sonlarına karşı aşırı hassastır. Birebir eşleşme ister, en ufak karakter kaymasında imza kırılır ve `permerror` üretir.
    
- **Relaxed:** Satır sonlarındaki ve gövdedeki fazla boşlukları, tab karakterlerini ve platform farklarını tolere eder.
    

## 📜 3. Çözüm Önerileri ve En İyi Uygulamalar

1. **Canonicalization Seçimi:** Kurumsal mail akışlarında, farklı işletim sistemlerine sahip gateway'lerin toleransı için ayar her zaman **`relaxed/relaxed`** (Header/Body) olarak set edilmelidir.
    
2. **Kriptografik Sıkılaştırma:** 1024 bit yerine güncel standart olan **2048 bit RSA** anahtarları kullanılmalıdır.
    
3. **DNS Chunking:** 2048 bit anahtarlar tek bir TXT satır limitini (255 karakter) aşabileceği için DNS üzerinde parçalı biçimde girilmelidir.
    

## 🗂️ 4. Örnek DKIM DNS Kayıtları ve Mimari Senaryolar

### A. 1024 bit Anahtar Yapısı (Tek Satır)

Anahtar boyutu kısa olduğu için tek parça halinde girilmesi yeterlidir:

Plaintext

```
default._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArvL1lH..."
```

### B. 2048 bit Anahtar Yapısı (Parçalı - Chunked)

255 karakterlik TXT sınırını aşmamak adına DNS editörüne tırnak işaretlerine ve boşluklara dikkat edilerek girilmelidir:

Plaintext

```
default._domainkey.example.com. IN TXT (
  "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArvL1lH..."
  "abc123xyz987...."
  "mno456pqr789...."
)
```

### C. Canonicalization Matrisi

|**Senaryo**|**Önerilen Ayar**|**Olası Etki / Risk**|
|---|---|---|
|Format farkı olmayan izole ortamlar|`simple/simple`|Güvenli fakat en ufak boşlukta kırılgan|
|Karma mimariler (Windows + Linux)|`relaxed/relaxed`|**Tavsiye Edilen;** yüksek toleranslı|
|Gövdeye müdahale edilen (Footer/Tagging) aktif ortamlar|`relaxed/relaxed`|**Yetersiz;** DKIM kalıcı olarak başarısız olur|

## 🔍 5. Teftiş ve Doğrulama (Verification & Test Tools)

DKIM yapılandırmasının ve üretilen imzaların geçerliliğini doğrulamak için aşağıdaki araçlar ve komut satırı yöntemleri kullanılmalıdır.

### A. Komut Satırı ile DNS Sorgulaması

Public key'in DNS'e doğru yansıyıp yansımadığını ve tırnak işaretlerinin doğruluğunu terminalden kontrol edin:

Bash

```
# Linux / Parrot OS terminalinden dig ile sorgulama
dig TXT default._domainkey.example.com
```

### B. Çevrimiçi Teftiş Platformları

|**Araç / Site**|**Kullanım Amacı**|
|---|---|
|[dkimvalidator.com](https://dkimvalidator.com/)|Gelen mailin ham başlıklarını inceleyerek DKIM ve SPF kontrolü yapar.|
|[mail-tester.com](https://www.mail-tester.com/)|Gönderilen e-postanın genel spam skorunu ve DKIM geçerliliğini puanlar.|
|[mxtoolbox.com](https://mxtoolbox.com/dkim.aspx)|DNS üzerindeki DKIM TXT kaydının formatını ve bütünlüğünü doğrular.|

## 🏁 Hâtime (Sonuç & Risk Yönetimi)

DKIM katmanında meydana gelen `permerror` hataları, kurumsal posta itibarını zedeleyerek DMARC politikalarının (`reject` veya `quarantine`) devreye girmesine ve meşru maillerin drop edilmesine sebep olur. Doğru canonicalization seçimi, imzalama motorunun akıştaki doğru konumu ve hatasız DNS chunking uygulaması ile kalıcı hataların önüne geçilmesi elzemdir.

Sübhâne rabbike rabbi’l-izzeti ammâ yasifûn. Ve selâmün ale’l-mürselîn. Ve’l-hamdü lillâhi rabbi’l-âlemîn.