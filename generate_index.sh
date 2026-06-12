#!/bin/bash

# ==============================================================================
# HULÂSA - Otomatik Fihrist (İndeks) Üretici
# Tanım: Mevcut indeks dosyasını yedekler ve güncel klasör yapısına göre yeniden üretir.
# ==============================================================================

INDEKS_DOSYASI="index.md"
YEDEK_DOSYASI="index.md.bak"

# 1. Mevcut İndeksi Yedekle
if [ -f "$INDEKS_DOSYASI" ]; then
    cp "$INDEKS_DOSYASI" "$YEDEK_DOSYASI"
    echo "[+] Mevcut $INDEKS_DOSYASI yedeklendi -> $YEDEK_DOSYASI"
fi

# 2. Yeni index.md İçin Dîbâce (Başlangıç Metni) Oluştur
cat << 'EOF' > "$INDEKS_DOSYASI"
# 🗺️ Kütüphane İndeksi (Fihrist)

Bu sayfa, `hulasa` bünyesindeki tüm teknik risale ve notların merkezi yönetim ve erişim noktasıdır. Bu dosya otomasyon scripti tarafından dinamik olarak güncellenmektedir.

---
EOF

# Tarancak ana kategoriler (Mevcut ve yeni eklenen klasörlerin sırası)
KATEGORILER=(
    "email-security"
    "endpoint-security"
    "linux-systems"
    "software-development"
    "offensive-security"
    "defensive-security"
    "quick-notes"
)

# 3. Klasörleri Tara ve İndekse Yaz
for klasor in "${KATEGORILER[@]}"; do
    if [ -d "$klasor" ]; then
        # Klasör ismini başlık formatına çevir (Örn: email-security -> Email Security)
        BASLIK=$(echo "$klasor" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
        
        echo -e "\n## 📂 $BASLIK" >> "$INDEKS_DOSYASI"
        
        # Klasör altındaki .md dosyalarını listele (A-Z sıralı)
        find "$klasor" -name "*.md" -not -path '*/.*' | sort | while read -r dosya; do
            
            # YAML frontmatter'dan başlığı çek (tırnak işaretlerini ve boşlukları temizle)
            NOT_BASLIGI=$(grep -m 1 '^title:' "$dosya" | sed -E 's/^title:[[:space:]]*"?(.*)"?/\1/' | sed 's/"//g')
            
            # Eğer frontmatter'da title alanı boşsa veya yoksa dosya adını başlık yap
            if [ -z "$NOT_BASLIGI" ]; then
                NOT_BASLIGI=$(basename "$dosya" .md | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            fi
            
            # Quick Notes için özel muamele: Yanına etiketleri (tags) de yazdır
            if [ "$klasor" == "quick-notes" ]; then
                ETIKETLER=$(grep -m 1 '^tags:' "$dosya" | sed -E 's/^tags:[[:space:]]*\[(.*)\]/\1/' | sed 's/,//g')
                if [ ! -z "$ETIKETLER" ]; then
                    # Virgülle ayrılmış etiketlerin başına # ekle
                    BICI_ETIKET=$(echo "$ETIKETLER" | sed 's/\([^ ]\+\)/#\1/g')
                    echo "- [$NOT_BASLIGI]($dosya) 🏷️ *${BICI_ETIKET}*" >> "$INDEKS_DOSYASI"
                else
                    echo "- [$NOT_BASLIGI]($dosya)" >> "$INDEKS_DOSYASI"
                fi
            else
                # Standart Kategoriler İçin Satır Ekle
                echo "- [$NOT_BASLIGI]($dosya)" >> "$INDEKS_DOSYASI"
            fi
        done
    fi
done

echo "[+] Yeni $INDEKS_DOSYASI başarıyla üretildi."
