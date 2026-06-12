#!/bin/bash

echo "[*] GitHub repodan güncel durum çekiliyor..."
git fetch origin

echo "[*] Sadece takip edilen dosyalar denetleniyor..."
echo "--------------------------------------------------------"

# 'git ls-files' sadece .gitignore tarafından yoksayılmayan dosyaları listeler
git ls-files "*.md" | while read -r dosya; do
    
    # Yerel statü (Dosya mevcut)
    LOCAL_STATUS=$(grep -m 1 '^status:' "$dosya" 2>/dev/null | sed -E 's/status:[[:space:]]*"?(.*)"?/\1/' | tr -d '[:space:]' | sed 's/"//g')
    
    # Remote (GitHub) statüsü
    REMOTE_STATUS=$(git show origin/main:"$dosya" 2>/dev/null | grep -m 1 '^status:' | sed -E 's/status:[[:space:]]*"?(.*)"?/\1/' | tr -d '[:space:]' | sed 's/"//g')

    # Eğer remote'da karşılığı yoksa (yeni eklenmiş ama henüz push edilmemiş)
    if [ -z "$REMOTE_STATUS" ]; then
        echo "[NEW] $dosya (Yerel: $LOCAL_STATUS | GitHub'da henüz yok)"
    # Eğer statüler farklıysa (Senkronizasyon sapması)
    elif [ "$LOCAL_STATUS" != "$REMOTE_STATUS" ]; then
        echo "[DIFF] $dosya (Yerel: $LOCAL_STATUS <-> GitHub: $REMOTE_STATUS)"
    fi
done

echo "--------------------------------------------------------"
echo "[+] Denetim tamamlandı (Yoksayılan dosyalar hariç)."