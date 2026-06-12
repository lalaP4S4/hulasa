---
title: SPF Mekanizmasında 10 DNS Lookup Limiti ve Kurumsal Mimarilerde SPF Dağılması Analizi
description: Büyük kurumsal yapılarda kontrolsüz include kullanımının RFC 7208 sınırlarına çarparak e-posta akışını kesintiye uğratma senaryosu ve mimari çözüm yolları.
category: email-security
tags:
  - spf
  - email-security
  - dns
  - troubleshooting
  - hardening
status: Ready
date: 2026-06-12
last_updated: 2026-06-12
---

> 💡 **Mebâdi-i Risale:** Bu doküman, e-posta kimlik doğrulama katmanının ilk baraj hattı olan SPF (Sender Policy Framework) mimarisinin, özellikle çoklu bulut servisleri (Salesforce, SAP, SendGrid vb.) kullanan kurumsal yapılarda uğradığı yapısal tıkanmaları (SPF Broken) incelemek; RFC 7208 standartlarında tanımlanan "10 DNS Lookup" limitinin kök nedenlerini ve bu limit aşıldığında ortaya çıkan `PermError` durumunu bertaraf edecek mimari çözüm stratejilerini yapılandırmak amacıyla kaleme alınmıştır.

---

## 1. Giriş ve Arka Plan (Zemin)

**SPF (Sender Policy Framework)**, e-posta dünyasının sahteciliğe karşı geliştirdiği en eski ve temel doğrulama protokollerinden biridir. Alıcı E-posta Güvenlik Ağ Geçidi (SEG - Secure Email Gateway), bir e-posta aldığında bağlantıyı kuran sunucunun IP adresini kaydeder. Ardından, e-postanın **Zarf Göndericisi (Envelope From / Return-Path)** adresindeki alan adının (domain) DNS kayıtlarına giderek `v=spf1` ile başlayan `TXT` kaydını sorgular.



### ⚠️ Kritik Mimari Ayrım: Header.From ve Envelope.From
SPF mekanizmasının en büyük yanılgısı, son kullanıcının Outlook veya Thunderbird gibi istemcilerde gördüğü `From:` (Header From) adresini koruduğu zannıdır. SPF, **yalnızca** SMTP oturumu açılırken `MAIL FROM` komutuyla iletilen ve hata raporlarının döneceği **Envelope From (Return-Path)** adresini doğrular. Bu nedenle SPF, tek başına `Header.From` sahteciliğini engelleyemez; tam bir koruma için **DMARC (Domain-based Message Authentication, Reporting, and Conformance)** hizalamasına (alignment) muhtaçtır.

---

## 2. Teknik Analiz ve Teşhis: 10 DNS Lookup Tuzağı

E-posta ağ geçitleri, internet üzerindeki bir alan adının SPF kaydını sorgularken sonsuz bir döngüye girmemek, DNS sunucularını Hizmet Dışı Bırakma (DoS) saldırılarına alet etmemek ve kaynak tüketimini optimize etmek zorundadır. Bu amaçla, **RFC 7208 (Bölüm 4.6.4)** standardı çok net ve katı bir sınır koymuştur:

> "SPF doğrulaması sırasında yapılan toplam mekanizma ve değiştirici (modifier) tabanlı DNS sorgusu sayısı **10'u geçemez**."

Eğer alıcı sunucu, sizin SPF kaydınızı çözümlerken 10'dan fazla DNS sorgusu yapmak zorunda kalırsa, süreci doğrudan durdurur ve doğrulamayı **`PermError` (Permanent Error)** olarak işaretler. Birçok sıkılaştırılmış kurumsal ağ geçidi (Örn: *Trend Micro DDEI*, *Cisco Secure Email*), SPF sonucu `PermError` olan e-postaları doğrudan karantinaya alır veya reddeder (Drop).

### 🔍 Hangi Mekanizmalar Sayacı Artırır?
SPF kaydı içindeki her ifade bu sayacı tetiklemez. Limit kuralları şöyledir:

| Limiti Artıran Mekanizmalar (+1)                       | Limiti Etkilemeyen Mekanizmalar (0)            |
| :----------------------------------------------------- | :--------------------------------------------- |
| `include:` (İçerideki kayda gitmek için)               | `ip4:` (Doğrudan IP bloku - sorgu gerektirmez) |
| `a` / `a:` (Alan adının A kaydını çözmek için)         | `ip6:` (Doğrudan IPv6 bloku)                   |
| `mx` / `mx:` (Alan adının MX sunucularını bulmak için) | `all` (Sürecin sonlandırıcı mekanizması)       |
| `redirect` (Tüm sorguyu başka domaine paslamak için)   |                                                |
| `exists` (Dinamik DNS kontrolü için)                   |                                                |

### 🚨 Örnek Senaryo: SPF Dağılması (SPF Broken)
Bir şirketin (Örn: `kurum.com`) ana DNS kaydı şu şekilde olsun:

```text
v=spf1 include:_spf.google.com include:servers.mcsv.net include:salesforce.com ~all
```
İlk bakışta sadece **3** `include` varmış gibi görünür. Ancak alıcı sunucu arka planda şu iç içe (nested) sorguları yapar:

1. `kurum.com` sorgulanır -> **(1)**
    
2. `_spf.google.com` çözümlenir -> İçeride `_netblocks.google.com`, `_netblocks2.google.com` vb. vardır. -> **(3 sorgu)**
    
3. `servers.mcsv.net` çözümlenir (MailChimp) -> Kendi içinde 2 alt include çağırır. -> **(3 sorgu)**
    
4. `salesforce.com` çözümlenir -> Salesforce altyapısı kendi içinde devasa bir include zincirine sahiptir. -> **(4+ sorgu)**
    

Sonuç olarak toplam DNS lookup sayısı **11** veya daha fazlasına ulaştığı an, kurumsal SPF kaydı teknik olarak **dağılır (broken)**. Artık dünyanın en güvenli sunucularından dahi mail atsanız, alıcı SEG’ler sizi güvensiz ilan edecektir.

## 3. Çözüm ve Uygulama (Sıkılaştırma Metotları)

Mimaride bu sınırı aşmak ve `PermError` tuzağından kurtulmak için uygulanabilecek üretime hazır (production-ready) çözüm yolları şunlardır:

### Çözüm A: Alt Domain Stratejisi (Subdomaining) - _En Sağlıklı Mimari_

Kurumsal ana domaini (`kurum.com`) sadece şirket içi çalışanların günlük yazışmalarına (Örn: Microsoft 365 veya Google Workspace) ayırın. Üçüncü parti toplu gönderim, pazarlama veya CRM servislerini alt domainlere bölün:

- Pazarlama mailleri (MailChimp/HubSpot): `pazarlama.kurum.com`
    
- Müşteri İlişkileri (Salesforce): `crm.kurum.com`
    
- İnsan Kaynakları / Bordro: `ik.kurum.com`
    

Bu sayede her alt domainin kendi SPF kaydı olacağından, her biri 10 lookup limitini sıfırdan başlatır ve ana domaininizin repütasyonunu korumuş olursunuz.

### Çözüm B: SPF Flattening (Düzleştirme) Betikleri

Eğer mimari olarak alt domain kullanılamıyorsa, `include` ifadelerinin arkasındaki alan adlarını düzenli aralıklarla (Örn: saatlik bir cron job ile) çözümleyip saf IP adreslerine dönüştüren otomasyonlar kullanılabilir.

Örneğin, `include:_spf.google.com` yazmak yerine, o include arkasındaki tüm güncel `ip4:X.X.X.X` blokları script vasıtasıyla çekilir ve ana SPF kaydına doğrudan IP olarak yazılır. IP blokları DNS lookup sayacını artırmadığı için limit problemi kökten çözülür. _(Risk: Üçüncü parti servis sağlayıcı IP bloklarını değiştirdiğinde, script çalışana kadar geçen sürede mailleriniz fail edebilir)._

### Çözüm C: Sözdizimi Sıkılaştırması (~all vs -all)

SPF kaydının sonundaki ibare, politikanızın sertliğini belirler:

- `~all` (SoftFail): E-postayı kabul et ama "şüpheli" olarak işaretle (Genelde DMARC devredeyse tercih edilir).
    
- `-all` (HardFail): Bu IP listede yoksa e-postayı doğrudan reddet (SEG seviyesinde en kesin sıkılaştırmadır).
    

Mimaride tüm harici servislerinizi temizleyip limitleri kalıcı olarak optimize ettikten sonra, politikayı güvenli bir şekilde `~all` seviyesinden `-all` seviyesine çekerek alan adınızın taklit edilme (spoofing) ihtimalini en aza indirmelisiniz.

## 🏛️ Hâtime (Kapanış)

Sübhâne rabbike rabbi’l-izzeti ammâ yasifûn. Ve selâmün ale’l-mürselîn. Ve’l-hamdü lillâhi rabbi’l-âlemîn.

**Hulasa-i Kelam:** SPF mekanizmasında 10 DNS lookup limiti, göz ardı edildiğinde kurumsal e-posta akışını felç edebilecek sessiz bir tehlikedir. Çözüm, kontrolsüzce her servisi ana domaine `include` etmek değil; alt domain tasnifini (nizam-ı tasnif) doğru kurgulamak ve sınırları mühendislik disipliniyle yönetmektir. Sinyali takip edin, gürültüyü birlikte filtreleyelim.