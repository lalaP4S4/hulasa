#!/bin/bash
# 🚀 HULÂSA - Yayınlama Betiği (Full Workflow)
set -e

echo "[*] 1. İndeks üretiliyor..."
./generate_index.sh

echo "[*] 2. Statüler güncelleniyor (Ready -> Published)..."
# SADECE git'in takip ettiği dosyalar üzerinde işlem yap
git ls-files "*.md" | while read -r file; do
    if grep -q 'status: "Ready"' "$file"; then
        sed -i 's/status: "Ready"/status: "Published"/g' "$file"
        echo "    [+] $file -> Published"
    fi
done

echo "[*] 3. .gitignore tazeleniyor (Draft dosyalar gizleniyor)..."
sed -i '/# HULASA_DRAFT/d' .gitignore
# .gitignore kontrolünü yine tüm dosyalarda yapmalıyız ki taslaklar sisteme girmesin
grep -l 'status: "Draft"' *.md */*.md 2>/dev/null | while read -r draft; do
    echo "$draft # HULASA_DRAFT" >> .gitignore
done

echo "[*] 4. Git senkronizasyonu başlatılıyor..."
git add .
git add -u

if git diff --cached --quiet; then
    echo "[-] Yayınlanacak yeni bir değişiklik yok."
    exit 0
fi

HOSTNAME=$(hostname)
DATE=$(date "+%Y-%m-%d %H:%M")
NUM_FILES=$(git diff --cached --name-only | wc -l)
git commit -m "hulasa: $DATE [$HOSTNAME] - $NUM_FILES rafine içerik yayına alındı"
git push origin "$(git branch --show-current)"

echo "✓ Fihrist ve içerikler başarıyla yayınlandı."