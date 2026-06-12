---
title: "DKIM Sorun Giderme: reason='key syntax error' Analizi ve Çözümü"
description: Alıcı e-posta sunucularında tetiklenen 'dkim=permerror reason=key syntax error' hatasının DNS kısıtlamaları, karakter kodlama uyuşmazlıkları çerçevesinde incelenmesi ve çözüm adımları.
category: Email Security
tags:
  - email-security
  - dkim
  - dns
  - troubleshooting
  - rfc-1035
status: "Published"
date: 2026-06-12
last_updated: 2026-06-12
---
# 🔍 DKIM Sorun Giderme: reason="key syntax error" Analizi

> 💡 **Mebâdi-i Risale:** Bu doküman, e-posta doğrulama süreçlerinde (L7 - Uygulama Katmanı) kriptografik imza kontrol aşamasına dahi geçilemeden sistemin kalıcı hata (`PermError`) üretmesine neden olan sözdizimsel (`syntax`) anomalilerin kök nedenlerini ve çözüm senaryolarını inceler.

---

## 1. Hatanın Anatomisi

Alıcı e-posta sunucusunun (MTA) loglarında veya e-postanın ham üst bilgisinde (header) yer alan `Authentication-Results` alanında aşağıdaki kırılım görüldüğünde:

```text
dkim=permerror reason="key syntax error" header.d=example.com header.s=selector1
````

Bu durum, alıcı sunucunun gönderici alan adına ait DNS kayıtlarından public key metnini başarıyla çektiğini, ancak çekilen bu metnin kriptografik veya sözdizimsel olarak **anlamlandırılamadığını (parse edilemediğini)** gösterir. Alıcı sunucu base64 formatında temiz bir veri beklerken, standart dışı bir yapıyla karşılaştığı için işlemi durdurmuştur.

## 2. Kök Neden Senaryoları (Root Cause Scenarios)

### Senaryo A: DNS Panel Sınırları ve "Görünmez Karakter" Tuzağı

2048-bit uzunluğundaki güçlü bir DKIM anahtar çifti base64 formatına döküldüğünde yaklaşık **340-360 karakter** uzunluğundadır.

- **Teknik Kısıtlama (RFC 1035):** DNS protokol standartlarına göre, tek bir metin (TXT) katarı en fazla **255 karakter** olabilir. Bu sınırı aşan verilerin DNS'e girilebilmesi için "String Chunking" (tırnak işaretleriyle parçalama) yöntemi kullanılmalıdır.
    
- **Anomali:** Yönetici metni elle parçalarken veya metin düzenleyiciden kopyalayıp panel arayüzüne yapıştırırken araya şu yapısal hatalar sızar:
    
    - Parçaların arasına yanlışlıkla ters bölü (`\`), fazladan çift tırnak (`""`) veya gizli satır sonu karakterleri (`\r\n`) girmesi.
        
    - Base64 karakter diziliminin en sonundaki doldurma (padding) karakteri olan `=` işaretinin eksik veya hatalı kopyalanması.
        

### Senaryo B: E-Posta Ağ Geçitlerinde (SEG) Karakter Kodlama Uyuşmazlığı

Kurumsal mimaride, merkezdeki posta sunucusu ile dış dünyaya maili basan uçtaki Secure Email Gateway (Ağ Geçidi) farklı üreticilere veya farklı işletim sistemlerine ait olduğunda karakter uyuşmazlığı yaşanabilir.

- **Anomali:** Gönderici taraf, başlıkları ve gövdeyi imzalayıp `DKIM-Signature` başlığını eklerken canonicalization ayarı olarak `simple` (katı/esnek olmayan) seçmiştir. Mail, çıkış kapısındaki SEG'e geldiğinde, gateway maili dışarı aktarırken karakter setini otomatik olarak **UTF-8**'den **ISO-8859-1**'e dönüştürürse veya başlık elemanlarındaki bazı boşlukları standardize etmek için yeniden yazarsa imzanın oturduğu sözdizimsel taban yolda bozulur. Alıcı sunucu, imzanın iddia ettiği sözdizimi kuralları ile taşınan veri yapısı çeliştiği için kriptografik analize hiç girmeden `key syntax error` basar.
    

## 3. Teşhis ve Soruşturma Adımları

### Adım 1: Ham DNS Verisinin Analizi

İlgili seçici (selector) üzerinden dış dünyaya yansıyan ham TXT kaydı çekilmeli ve görünmez karakter sızıntıları incelenmelidir:

Bash

```
# Ham DKIM kaydını dig ile çekme
dig TXT selector1._domainkey.example.com +short

# Çıktıdaki tırnakların ve boşlukların nizami olup olmadığını kontrol edin:
# Örnek Sorunlu Çıktı: "v=DKIM1; k=rsa; p=MIIB...""\n...extra_space..."
```

### Adım 2: Base64 Sözdizimi Doğrulaması

DNS kaydındaki `p=` etiketinin karşısında duran public key değeri izole edilmeli ve terminal üzerinde base64 validasyonuna tabi tutulmalıdır:

Bash

```
# Anahtar değerini base64 decode testinden geçirme
echo -n "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8..." | base64 -d > /dev/null
if [ $? -ne 0 ]; then
    echo "[-] Kritik Hata: DKIM Public Key içerisinde geçersiz Base64 karakterleri veya sözdizimi tespit edildi!"
fi
```

## 4. Çözüm ve Sıkılaştırma (Remediation)

|**Problem Kaynağı**|**Tetikleyici Unsur**|**Kalıcı Çözüm**|
|---|---|---|
|**DNS Chunking Hatası**|255 karakter sınırında tırnakların yanlış yönetilmesi.|DNS kaydını tek satırda, parantez blokları içinde yapılandırmak: `( "part1..." "part2..." )`|
|**Base64 Bozulması**|Anahtar metninin içine görünmez boşluk sızması.|`dig` çıktısını ham metin editöründe regex `[^A-Za-z0-9+/=]` kalıbıyla taratarak illegal karakterleri temizlemek.|
|**MTA Header Manipülasyonu**|Sunucular arası aktarımda başlık yapısının değişmesi.|Gönderici imzalama motorunda Canonicalization ayarını **`relaxed/relaxed`** (Header/Body) moduna çekmek.|

## 5. Hâtime (Mühendislik Özeti)

`reason="key syntax error"`, sistemlerin veri iletim kanallarında ve isim sunucularında RFC standartlarına ne kadar hassas bağlı kalması gerektiğini gösteren kritik bir göstergedir. Siber güvenlik mimarilerinde e-posta akış hattının kesintiye uğramaması adına, altyapıdaki tüm DNS girdilerinin otomasyon araçlarıyla kontrol edilmesi ve imzalama Canonicalization ayarlarının esnek (`relaxed`) tutulması defansif sıkılaştırmanın temel adımlarından biridir.