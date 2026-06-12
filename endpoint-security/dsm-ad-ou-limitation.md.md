
Bismillâhirrahmânirrahîm.

Hamd-i bî-pâyân âlemlerin Rabbi olan Allah Teâlâ’ya; salât ü selâm-ı bî-nihâye Enbiyâlar Serveri Efendimiz Hazret-i Muhammed’e, O'nun âl ve ashâbının cümlesine olsun.

Tenzih ve takdis ederiz ki, Senin bize tâlim buyurduğundan gayrı hiçbir ilmimiz yoktur; muhakkak ki Alîm and Hakîm olan ancak Sensin. Kezâlik, Senin bize ihsan ve tefhim buyurduğundan başka hiçbir fehmimiz ve idrakimiz yoktur; şüphesiz Cevâd ve Kerîm olan ancak Sensin.

Emmâ ba'd;

# 📑 Deep Security Manager (DSM) Üzerinde Active Directory Bilgisayar Görünürlüğünü Sınırlandırma

> **Mebâdi-i Aşere (Hulasa-i Kelâm):**
> - **Had (Tanım):** Deep Security Manager'ın (DSM) entegre edildiği Active Directory (AD) yapısındaki tüm bilgisayarları listeleme davranışını, ACL (Access Control List) manipülasyonu ile sadece belirli Organizasyon Birimleri (OU) düzeyinde sınırlandırma usulüdür.
> - **Gâye (Amaç):** DSM arayüzündeki varlık (asset) karmaşasını önlemek, yetkilendirme sınırlarını korumak ve lisans/izleme dışı kalması gereken sistemleri izole etmek.
> - **Semere (Fayda):** Performans optimizasyonu, temiz envanter yönetimi ve alt ekipler için rafine bir merkezi yönetim paneli.

---

## 🏛️ 1. Dîbâce (Executive Summary & Tehdit Profillemesi)

Deep Security Manager (DSM) mimarisinde, bir Domain Kullanıcı hesabı vasıtasıyla Active Directory entegrasyonu sağlandığında, ürün varsayılan olarak dizindeki tüm bilgisayar nesnelerini envantere dahil eder. DSM konsolunda yerel bir filtreleme mekanizması (sadece belirli OU'ları göster gibi) bulunmamaktadır.

Bu durum, özellikle büyük ölçekli kurumsal yapılarda gereksiz kaynak tüketimine ve envanter kirliliğine yol açar. Bu döküman, DSM tarafında bir kod değişikliği veya harici bir ajan kullanımı yerine, Active Directory nesne izinleri (Object Permissions) üzerinde **"Deny Read"** mantığı uygulanarak bu kısıtlamanın nasıl proaktif olarak yapılacağını açıklamaktadır.

* **İlgili Katman:** Endpoint Security / Merkezi Güvenlik Yönetimi
* **Risk Derecesi:** Düşük (Operasyonel Kolaylık)
* **Referanslar / Standartlar:** Trend Micro Deep Security Administrator Guide / Active Directory ACL Hardening

---

## 🛠️ 2. Usul ve Tatbikat (Technical Implementation)

### A. Ön Gereksinimler
- Active Directory üzerinde Domain Admin yetkisi *(İlk ACL yapılandırmasını icra edebilmek için).*
- Deep Security Manager (DSM) üzerinde AD senkronizasyon yetkisine sahip bir yönetici hesabı.

### B. Adım Adım Yapılandırma Prosedürü

> [!CAUTION]
> **Nizam-ı Sıra Kritik:** Active Directory nesne izinleri ve kullanıcı gruplama hiyerarşisi aşağıda belirtilen sıra ile işletilmezse, DSM senkronizasyonu hata verecektir veya tüm dizini okumaya devam edecektir.

#### Adım 1: Servis Hesabı ve Güvenlik Grubu Oluşturma
Active Directory Users and Computers (ADUC) konsolunu açın ve ilgili dizin altında şu nesneleri inşa edin:
- **Servis Kullanıcısı:** `dsroot`
- **Güvenlik Grubu:** `dsroots` *(Global Security Group)*

#### Adım 2: Hesap Güvenlik Politikalarını Sıkılaştırma
`dsroot` kullanıcısının özelliklerine (`Properties`) girerek `Account` sekmesi altındaki güvenlik bayraklarını (flags) aşağıdaki gibi set edin:
- [ ] `The User must change password at next logon` onay kutusunun işaretini **kaldırın**.
- [x] `Password never expires` onay kutusunu **işaretleyin**.

#### Adım 3: Grup Üyeliğini ve İzolasyon Modunu Yapılandırma
Kullanıcının standart yetkilerini tamamen sıfırlamak ve sadece `dsroots` grubu üzerinden yetkilendirmek için:
1. `dsroot` kullanıcısını `dsroots` grubuna üye olarak ekleyin.
2. `Member Of` sekmesinde `dsroots` grubunu seçerek **Set Primary Group** butonuna tıklayın.
3. Bir önceki adım tamamlandıktan sonra, listede yer alan standart **Domain Users** grubunu seçin ve **Remove** diyerek kaldırın.

> [!WARNING]
> Hesabı `Domain Users` grubundan arındırmadan yapılacak "Deny Read" izinleri, `Domain Users`'ın genel okuma yetkisinden dolayı bypass edilebilir. Bu yüzden izolasyon adımı eksiksiz uygulanmalıdır.

#### Adım 4: Advanced Features ve Gizleme Operasyonu (ACL Manipülasyonu)
1. ADUC konsolunda üst menüden **View -> Advanced Features** özelliğini aktif hale getirin.
2. **DSM konsolunda görünmesini istemediğiniz** her bir OU (Organizasyon Birimi) için şu adımları tatbik edin:
   - İlgili OU'ya sağ tıklayıp **Properties** menüsüne gelin.
   - **Security** sekmesine geçiş yapın ve **dsroots** grubunu listeye ekleyin.
   - *Permissions for dsroots* bölümünde **READ** izninin hizasındaki **Deny** kutucuğunu işaretleyin.
   - Gelen sistem uyarısını onaylayarak kaydedin.

#### Adım 5: DSM Entegrasyonunun Tamamlanması
Deep Security Manager konsoluna giriş yapın. `Computers -> Add Active Directory` sihirbazında servis hesabı kimlik bilgileri olarak yeni oluşturduğunuz ve domain yetkileri kısıtlanmış `dsroot` kullanıcısını tanımlayarak senkronizasyonu başlatın.

---

## 🔍 3. Teftiş ve Doğrulama (Verification & Auditing)

Yapılandırmanın sıhhatini kontrol etmek için DSM konsolunda manuel tetikleme gerçekleştirilmeli ve yetkiler test edilmelidir.

### A. Konsol Doğrulaması
DSM üzerinden manuel senkronizasyon tetiklendikten sonra bilgisayar ağacını kontrol edin:
- İzin verilen OU altındaki bilgisayarlar $\rightarrow$ **Görünür** *(Gözle Kontrol: Başarılı)*
- "Deny Read" uygulanan OU altındaki bilgisayarlar $\rightarrow$ **Gizli/Listelenmiyor** *(Gözle Kontrol: Başarılı)*

### B. Terminal Üzerinden Yetki Simülasyonu
Active Directory tarafında `dsroot` kullanıcısının gözünden sistemi simüle etmek ve ACL'in çalıştığından emin olmak için terminal üzerinden şu doğrulama yapılabilir:

```powershell
# runas komutu ile dsroot komut satırı izole olarak açılır
runas /user:YOURDOMAIN\dsroot cmd

# Açılan yeni CMD satırında dsquery ile kısıtlanan OU altındaki nesneleri sorgulayın
# Erişim engellendiği için çıktı boş dönmelidir
dsquery computer "OU=KisitliOU,DC=yourdomain,DC=local"
````

## 🏁 Hâtime (Sonuç & Risk Yönetimi)

Bu yöntemle DSM, sadece `dsroot` kullanıcısının okuma yetkisi olan (yani Deny Read uygulanmamış) OU ağaçlarını ve altındaki bilgisayarları envanterine dahil edecektir.

> [!NOTE] **Kritik Operasyonel Risk Notu:** İlerleyen süreçte DSM takibine alınması veya yeni bir kural politikasına dahil edilmesi gereken kısıtlı bir OU açıldığında, o OU üzerindeki `dsroots` grubuna ait **Deny Read** izninin kaldırılması unutulmamalıdır. Aksi halde sistemlerin neden DSM envanterine düşmediğine dair sorun giderme (troubleshooting) süreçleri uzayabilir.

Sübhâne rabbike rabbi’l-izzeti ammâ yasifûn. Ve selâmün ale’l-mürselîn. Ve’l-hamdü lillâhi rabbi’l-âlemîn.
