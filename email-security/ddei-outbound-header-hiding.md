---
title: "Trend Micro DDEI'da Outbound Header Hiding: Undocumented Postfix ve SSH ile Sıkılaştırma Rehberi"
date: 2026-06-11
category: "Email Security"
tags: [ddei, trend-micro, postfix, hardening, outbound]
status: production
---

> **Bismillâhirrahmânirrahîm.**
> 
> **Elhamdülillâhi Rabbi’l-âlemîn, vesselâtü vesselâmü alâ Rasûlinâ Muhammedin ve alâ âlihî ve sahbihî ecmaîn.**
> 
> **Sübhâneke lâ ilme lenâ illâ mâ allemtenâ, inneke ente’l-alîmü’l-hakîm. (Bakara-32)**
> 
> **Sübhâneke lâ fehme lenâ illâ mâ fehhemtenâ, inneke ente’l-cevâdü’l-kerîm.**
> 
> **Ammâ ba’d;**

Kurumsal e-posta güvenliğinde sıkılaştırma (**hardening**) dendiğinde akla ilk gelen adımlardan biri, dış dünyaya giden e-postalardaki hassas iç ağ bilgilerini gizlemektir. E-posta üstbilgilerinde (**headers**) sızan dahili IP adresleri, iç ağdaki Exchange veya Relay sunucularının FQDN (tam nitelikli alan adı) bilgileri, siber saldırganların keşif (**reconnaissance**) aşamasında organizasyon şemanızı ve topolojinizi kolayca haritalandırmasına neden olur.

Ancak **Trend Micro Deep Discovery Email Inspector (DDEI)** kullananların bildiği üzere, cihazın web arayüzünde (GUI) giden maillerdeki bu header’ları esnek bir şekilde “tıraşlayabileceğiniz” doğrudan bir menü bulunmaz.

Peki ne yapacağız? DDEI’ın kalbinde yatan **Postfix** mimarisinin gücünden ve cihazın işletim sistemi (OS) seviyesindeki gizli yeteneklerinden yararlanacağız. Bu rehberde; DDEI’ın arka kapısını nasıl açacağınızı, gelen mail analizini bozmadan **sadece giden (outbound)** mailleri nasıl filtreleyeceğinizi ve tescilli `X-` header'larını tamamen kapatmanın yollarını adım adım inceliyoruz.

---

## 1. Neden Standart “header_checks” Değil?

Postfix kullanan sysadmin’lerin eli genellikle doğrudan `header_checks` parametresine gider. Ancak DDEI gibi bir e-posta güvenlik gateway'inde bunu yapmak büyük bir hatadır.

`header_checks` yönergesi **global** çalışır; yani hem gelen (inbound) hem de giden (outbound) e-postaları filtreler. Eğer bu kuralı körlemesine uygularsanız, DDEI'ın içeriye gelen maillerdeki spam, oltalama veya zararlı yazılım analizlerini besleyen kritik header verilerini de silersiniz ve cihazı bir nevi kör edersiniz.

Bizim amacımız, filtrelemeyi sadece SMTP istemci çıkış aşamasına (**SMTP client submission**) izole etmek. Bunun için Postfix'in **`smtp_header_checks`** mekanizmasını kullanacağız.

---

## 2. Aşama: Gizli Sayfayı Açmak ve Root Yetkisi Almak

DDEI, yapısı gereği root SSH bağlantılarına doğrudan izin vermez. İşletim sistemi seviyesine inmek için Trend Micro’nun resmi olmayan ama sahada hayat kurtaran prosedürünü izlememiz gerekiyor.

### Adım 1: Hidden RDQA Sayfasına Giriş
DDEI yönetim konsoluna admin yetkileriyle giriş yaptıktan sonra tarayıcınızın adres satırına şu gizli adresi yazarak gizli kalite güvence sayfasına ulaşın:
```text
https://<DDEI-IP-ADRESINIZ>/hidden/rdqa.php
````

Bu sayfada yer alan **Remote Management (SSH)** seçeneğini aktif hale getirin.

### Adım 2: Trend Micro Destek Ekibinden Token Talebi

Cihaza root olarak bağlanabilmek için dinamik bir challenge-response token’ına ihtiyacınız var. **success.trendmicro.com** adresindeki kurumsal hesabınız üzerinden ivedi bir destek talebi (Case) açın ve sisteminiz için root SSH erişim token’ı (ek doğrulama kodu) talep edin.

### Adım 3: SSH ile Root Bağlantısının Kurulması

Token tarafınıza ulaştıktan sonra bir terminal açarak cihaza bağlanın:

```
ssh root@<DDEI-IP-ADRESINIZ>
```

> 🔑 **Şifre Notu:** DDEI web arayüzünde kullandığınız admin şifresi ile root şifresi aynıdır. Kimlik doğrulama esnasında sizden destek ekibinden aldığınız o ek token istenecek, onu girerek oturumu açın.

## 3. Aşama: Postfix Üzerinde Outbound İzolasyonu

DDEI’ın Postfix bileşenleri standart Linux dizinlerinde değil, `/opt/trend/ddei/postfix/` dizini altında izole edilmiştir. Bu yüzden tüm komutları bu patika üzerinden yürüteceğiz.

> 💡 **Kılavuz: Terminalde Dosya Düzenleme (vi) Pratikleri**
> 
> Aşağıdaki adımlarda dosyaları düzenlemek için Linux’un yerleşik `vi` editörünü kullanacağız. Aşina değilseniz aşağıdaki adımları sırasıyla takip edin:
> 
> 1. **Dosyayı Açın:** `vi dosya_adi` komutunu yazıp Enter'a basın. (Okuma modu)
>     
> 2. **Düzenleme Moduna Geçin:** Klavyeden **`i`** tuşuna basın. Sol altta `-- INSERT --` yazısı görünmelidir.
>     
> 3. **Yazmayı Bitirin:** Düzenleme bittiğinde klavyeden **`Esc`** tuşuna basarak yazma modundan çıkın.
>     
> 4. **Kaydedip Çıkın:** Ekranın alt kısmına **`:wq`** (Write and Quit) yazıp Enter'a basın.
>     
> 5. **Kaydetmeden Çıkın:** Hatalı bir işlemde kaydetmeden çıkmak için **`:q!`** yazıp Enter'a basın.
>     

### Adım 1: `smtp_header_checks` Filtre Dosyasını Oluşturun

Dışarı giden e-postalardan temizlemek istediğiniz header kalıplarını regex formatında bu dosyaya yazacağız. İlgili dizinde dosyayı oluşturup açın:

```
vi /opt/trend/ddei/postfix/etc/postfix/smtp_header_checks
```

Açılan dosyanın içerisine, aşağıdaki optimize edilmiş kurumsal şablonu yapıştırın. Kendi yapınıza göre düzenlemeleri yapmayı unutmayın:

```
#############################################################################
# POSTFIX OUTBOUND SMTP_HEADER_CHECKS TEMPLATE FOR TREND MICRO DDEI
# Version: v3.0.1 (2026-06) 
# 
# ! KRİTİK UYARI: Bu dosya sadece dışarı giden (Outbound) e-postalar için
# kullanılmalıdır. Dış dünyaya ait genel/kamusal IP veya MX adreslerini
# ENGELLEMEYİNİZ. Sadece kurumsal iç ağ yapınızı hedefleyin.
# Bu liste genel kullanılan headerları içermektedir. Bu listede
# kullanmayacağınız satırların başına # işareti koyarak kapatabilirsiniz.
# Buradaki veriler sadece örnektir. Kendi verilerinizi girerek güncelleyiniz.
# by l414p454
#############################################################################

# =========================================================================
# 1. TREND MICRO DDEI & ANTISPAM HEADER FILTERS
# =========================================================================
# Giden e-postalardaki DDEI/TMASE analiz ve itibar izlerini temizler.

# Email Reputation (ERS) Gizleme - Giden mail gateway IP'nize göre uyarlayın
/^X-TM-AS-ERS:\s+(10\.0\.18\.81)-.*$/                      IGNORE

# Mail Sunucu internal Hostname Base64 Maskeleme (Örn: posta.kurum.com.tr 
# base64 hali) base64 halini bulmak için cyberchef aracından yararlanın.
# link: https://gchq.github.io/CyberChef/#recipe=To_Base64('A-Za-z0-9%2B/%3D
/^X-TM-AS-SMTP: 1\.0 cG9zdGEua3VydW0uY29tLnRyIA==/          IGNORE

# Trend Micro DDEI Analiz ve Güvenlik Header Bilgileri
/^X-DDEI-TLS-USAGE.*/                                      IGNORE
/^X-TMASE-Version.*/                                       IGNORE
/^X-TMASE-Result.*/                                        IGNORE
/^X-TMASE-XGENCLOUD.*/                                     IGNORE
/^X-TMASE-MatchedRID.*/                                    IGNORE
/^X-TMASE-SNAP-Result.*/                                   IGNORE
/^X-TMASE-INERTIA.*/                                       IGNORE
/^X-TM-AS-Result.*/                                        IGNORE

# =========================================================================
# 2. TREND MICRO SMEX (ScanMail for Exchange) FILTERS
# =========================================================================
# Organizasyon içinde SMEX kullanılıyorsa dışarı sızan ürün izlerini siler.

/^X-TM-AS-Product-Ver: SMEX-.*/                            IGNORE
/^X-TM-AS-User-Approved-Sender:.*/                         IGNORE
/^X-TM-AS-User-Blocked-Sender:.*/                          IGNORE
/^X-TM-SNTS-SMTP:.*/                                       IGNORE

# =========================================================================
# 3. INTERNAL NETWORK & TOPOLOGY OBFUSCATION (Received Headers)
# =========================================================================
# İç ağdaki posta sunucu isimlerini ve lokal IP bloklarını dış dünyadan gizler.
# Tüm iç IP ve iç hostname bilgileri burada. DIŞ IP yazılmamalı.

/^Received: from posta\.kurum\.com\.tr.*/                  IGNORE
/^Received: from (.*10\.0\.1\.1.*)/                        IGNORE
/^Received: from (.*127\.0\.0\.1.*)/                       IGNORE

# =========================================================================
# 4. MAIL SERVER SPECIFIC HEADERS (Zimbra, Local Mailers etc.)
# =========================================================================
# Sunucu katmanında eklenen versiyon ve tarama bilgilerini temizler.

/^X-Mailer:.*/                                             IGNORE
/^X-Zimbra-DL:.*/                                          IGNORE
/^X-Virus-Scanned:.*/                                      IGNORE

# =========================================================================
# 5. MICROSOFT / EXCHANGE SPECIFIC HEADERS
# =========================================================================
# Exchange sunucularının eklediği ve son kullanıcının iç IP'sini sızdıran
# veya iç mesajlaşma trafiğine ait kurumsal header'ları temizler.

/^x-originating-ip:.*/                                     IGNORE
/^X-MS-.*/                                                 IGNORE
/^X-Microsoft-.*/                                          IGNORE
/^Thread-Index:.*/                                         IGNORE
/^Thread-Topic:.*/                                         IGNORE
```
### Adım 2: `main.cf` Konfigürasyonunu Düzenleyin

Şimdi Postfix’e bu filtreyi sadece outbound trafiğinde okuması gerektiğini söyleyeceğiz. Öncesinde ana konfigürasyon dosyasının mutlaka yedeğini alın:

```
# Yedekleme
cp /opt/trend/ddei/postfix/etc/postfix/main.cf /opt/trend/ddei/postfix/etc/postfix/main.cf.bak

# Düzenleme
vi /opt/trend/ddei/postfix/etc/postfix/main.cf
```
Dosyanın en alt satırına inip şu yorum satırlarını ve parametreyi ekleyin:
```
# Using smtp_header_checks for Outbound Header Hiding
smtp_header_checks = regexp:/opt/trend/ddei/postfix/etc/postfix/smtp_header_checks
```
### Adım 3: Yapılandırmayı Yeniden Yükleyin

Değişikliklerin Postfix mail sistemine hemen yansıması için sistemi reload edin:

```
postfix reload
```
## 4. Doğrulama ve Risk Yönetimi

Yaptığınız işlemlerin doğruluğundan emin olmak için iki yönlü test senaryosu uygulamalısınız:

- **Giden (Outbound) Testi:** Dahili bir hesaptan harici bir adrese (Gmail, ProtonMail vb.) test e-postası gönderin. Alıcı tarafında mailin ham verisini (_View Raw / Show Original_) inceleyin. `X-TM-` veya iç ağ IP adreslerinizin başarıyla gizlendiğini teyit edin.
    
    > ℹ️ **Not:** DDEI üzerinde _Message Tracking_ loglarında mail sunucunuzdan gelen IP bilgisi artık `Unknown` olarak görünecektir. Bu beklenen ve mimarinin çalıştığını gösteren bir durumdur.
    
- **Gelen (Inbound) Testi:** Dışarıdan içeriye bir mail atın ve DDEI’ın bu maile ait header’ları bozmadığını, antispam ve güvenlik analizlerinin loglarda sorunsuz tetiklendiğini görün.
    
> **Sübhâne rabbike rabbi’l-izzeti ammâ yasifûn. Ve selâmün ale’l-mürselîn. Ve’l-hamdü lillâhi rabbi’l-âlemîn.**