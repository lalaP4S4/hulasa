---
title: DKIM PermError Soruşturması ve Çözüm Analizi
description: E-posta ağ geçitlerinde ve doğrulama hatlarında karşılaşılan 'DKIM PermError (permanent error)' hatasının kök neden analizi, RFC standartları çerçevesinde incelenmesi ve çözüm metodolojileri.
tags:
  - email-security
  - dkim
  - dns
  - troubleshooting
  - defensive-security
status: "Published"
date:
last_updated: 2026-06-12
---
# 🛡️ DKIM PermError Soruşturması ve Kök Neden Analizi

> 💡 **Mebâdi-i Risale:** Bu doküman, gelen e-posta trafiğinin kimlik doğrulama katmanında (L7 - Application Katmanı SMTP Güvenliği) sıkça rastlanan ve meşru e-postaların dahi karantinaya düşmesine veya reddedilmesine sebep olan `dkim=permerror` durumunu teknik derinliğiyle analiz etmek amacıyla kaleme alınmıştır.

---

## 1. Problemin Teşhisi (Problem Definition)

E-posta güvenlik ağ geçitleri (SEG), alıcı sunucular veya DMARC raporlama mekanizmaları, gelen bir e-postanın `Authentication-Results` başlığında (header) aşağıdaki gibi bir hata kırılımı raporlayabilir:

```text
Authentication-Results: mx.local;
       dkim=permerror reason="key syntax error" header.d=example.com header.s=selector1;
       dmarc=fail (p=reject) action=reject header.from=example.com;
````

### Hata Karakteristiği

- **Hata Türü:** Kalıcı Hata (Permanent Error).
    
- **Etkisi:** DKIM doğrulaması `Fail` kabul edilir. Eğer alan adının sert bir DMARC politikası (`p=quarantine` veya `p=reject`) varsa ve SPF hizalaması (alignment) kurtarmıyorsa, e-posta doğrudan engellenir.
    
- **Kritik Ayrım:** `TempError` (Geçici DNS timeout durumları) aksine, `PermError` durumunda e-posta altyapısı tekrar deneme yapmaz; kaydın veya imzanın kalıcı olarak bozuk olduğuna hükmeder.
    

## 2. Kök Neden Analizi (Root Cause Analysis - RCA)

`DKIM PermError` hatası, temel olarak iki ana kaynaktan meydana gelir: **DNS tarafındaki kayıt bozuklukları** veya **MTA/SEG katmanındaki imzalama/şifreleme uyumsuzlukları**.

### Senaryo A: DNS TXT Kaydındaki Sözdizimi Hataları (Syntax Errors)

RFC 6376 standartlarına göre, bir DNS DKIM TXT kaydı belirli etiketler (tags) ve kurallarla yazılmalıdır. En sık yapılan hatalar şunlardır:

1. **Gereksiz Karakter Sızıntıları:** Kayıt kopyalanırken satır sonu karakterleri (`\n`), ters bölü (`\`) veya görünmez boşlukların DNS paneline yapışması.
    
2. **Yatık Tırnak (Quotation Mark) Sorunları:** 2048-bit RSA anahtarları tek bir TXT kaydı sınırını (255 karakter) aştığı için split (bölünmüş) mimaride yazılır. Bu bölünme esnasında tırnakların yanlış kapatılması anahtarın bütünlüğünü bozar.
    
3. **Kritik Etiket Hataları:** `p=` (public key) etiketinin başında veya sonunda boşluk kalması, `k=rsa` tanımlamasında hata yapılması.
    

### Senaryo B: İmzalama Esnasındaki Karakter Dönüşümleri (Header/Body Modification)

E-posta gönderen taraftaki bir ara sunucu (Internal Mail Server, DLP, Antivirüs Ajanı vb.), mesajın başlıklarını veya gövdesini imza atıldıktan sonra değiştirirse, alıcı taraftaki hash doğrulaması tutmaz ve `PermError` tetiklenebilir:

- **Header Canonicalization (Hizalama):** `simple` veya `relaxed` algoritmalarının sınırlarını aşan büyük harf/küçük harf dönüşümleri.
    
- **Body Alteration:** E-postanın altına otomatik eklenen yasal uyarılar (disclaimer) veya yazı tipi dönüştürmeleri.
    

## 3. Teşhis ve Doğrulama Metodolojisi (Verification Steps)

Problemin kaynağını tespit etmek için L7 SMTP simülasyonu ve DNS sorgulama katmanları izole edilmelidir.

### Adım 1: DNS Katmanının Sorgulanması

İlgili seçici (selector) ve alan adı üzerinden ham TXT kaydı çekilmeli ve karakter analizi yapılmalıdır.

Bash

```
# Ham DKIM kaydını dig ile çekme
dig TXT selector1._domainkey.example.com +short

# Çıktıda tırnak işaretlerinin ve boşlukların kontrolü:
# Örn: "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
```

### Adım 2: Sözdizimi (Parser) Kontrolü

Ham anahtar metni üzerinde base64 validasyonu yapılmalıdır. Eğer anahtarın içinde geçersiz bir karakter varsa, aşağıdaki komut decode hatası verecektir:

Bash

```
# p= etiketindeki değeri izole edip base64 decode testi yapma
echo -n "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8..." | base64 -d > /dev/null
if [ $? -ne 0 ]; then
    echo "[-] Hata: DKIM Public Key içerisinde geçersiz Base64 karakterleri tespit edildi!"
fi
```

## 4. Çözüm ve Sıkılaştırma (Mitigation & Hardening)

Problemin kalıcı olarak çözülmesi için aşağıdaki aksiyon planı uygulanmalıdır:

|**Katman**|**Aksiyon Maddesi**|**RFC Referansı**|
|---|---|---|
|**DNS Yönetimi**|2048-bit uzunluğundaki anahtarlar DNS sağlayıcısına girilirken tek parça halinde değil, sağlayıcının sınırlarına uygun şekilde ("part1" "part2") tırnaklarla ayrılmış formatta girilmelidir.|RFC 1035 / RFC 6376|
|**SEG Yapılandırması**|Gönderim yapılan Mail Gateway üzerinde DKIM canonicalization ayarı `relaxed/relaxed` olarak güncellenmelidir. Bu sayede boşluk ve küçük/büyük harf esnemelerine izin verilir.|RFC 6376 Section 3.4|
|**Anahtar Değişimi**|Eğer mevcut private/public key çiftinde yapısal bir bozulma varsa, eski seçici (selector) emekliye ayrılmalı (revocation) ve yeni bir selector ile temiz anahtar üretilmelidir.|-|

### Örnek Doğru DNS Kayıt Formatı (Splitted RSA-2048)
```
v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Y...[255 karakter]... " " ...[geri kalan karakterler]...
```
## 5. Mühendislik Notları (Architectural Verdict)

`DKIM PermError`, sistemlerin esnek mimariler tasarlarken RFC standartlarına ne kadar sıkı bağlı kalması gerektiğini gösteren bir L7 Application katmanı klasiğidir. E-posta hattındaki otomasyon ve güvenlik scriptlerinin bu tür anomalileri parse edebilmesi adına, log analiz şablonlarına `reason="key syntax error"` regex paternlerinin eklenmesi defansif mimariyi tahkim edecektir. Bu konu ayrı bir makale konusu olarak [DKIM Sorun Giderme: reason='key syntax error' Analizi ve Çözümü](email-security/dkim-key-syntax-error) işlenmiştir.
