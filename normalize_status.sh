#!/bin/bash

# Geçerli durumlar listesi
VALID_STATUSES=("Draft" "Staged" "Ready" "Published" "Deprecated")

echo "[*] Makale status durumları taranıyor..."

find . -name "*.md" -not -path '*/.*' | while read -r dosya; do
    # Dosya içindeki mevcut status değerini çek
    CURRENT_STATUS=$(grep -m 1 '^status:' "$dosya" | sed -E 's/status:[[:space:]]*"?(.*)"?/\1/' | tr -d '[:space:]' | sed 's/"//g')

    if [ -z "$CURRENT_STATUS" ]; then
        echo "[!] Uyarı: $dosya içerisinde 'status' bulunamadı!"
        continue
    fi

    # Değer geçerli mi kontrol et
    IS_VALID=false
    for s in "${VALID_STATUSES[@]}"; do
        if [[ "$CURRENT_STATUS" == "$s" ]]; then
            IS_VALID=true
            break
        fi
    done

    # Geçerli değilse düzeltme yap
    if [ "$IS_VALID" = false ]; then
        echo "[?] $dosya -> Mevcut status '$CURRENT_STATUS' standart dışı."
        
        # Burada 'production' gibi eski değerleri 'Published'e eşleyebilirsin
        if [[ "$CURRENT_STATUS" == "production" ]]; then
            sed -i 's/status:.*production/status: "Published"/' "$dosya"
            echo "    [+] '$CURRENT_STATUS' -> 'Published' olarak güncellendi."
        else
            echo "    [!] $dosya status değeri tanımlanamadı. Lütfen manuel kontrol edin."
        fi
    fi
done

echo "[+] Tarama tamamlandı."
