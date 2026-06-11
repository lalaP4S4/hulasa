#!/bin/bash

# Hata durumunda scriptin durmasını sağla
set -e

# Cihaz adı, tarih ve saat değişkenlerini tanımla
HOSTNAME=$(hostname)
DATE=$(date "+%Y-%m-%d %H:%M")

# 1. Değişiklikleri Git'e ekle
git add .

# 2. Değişen/eklenen toplam dosya sayısını hesapla
# (Sadece stage edilmiş, yani commit'lenecek benzersiz dosyaları sayar)
NUM_FILES=$(git diff --cached --name-only | wc -l)

# Eğer değişen dosya yoksa işlem yapmadan çık
if [ "$NUM_FILES" -eq 0 ]; then
    echo "Önemli: Değişiklik saptanmadı. Yedekleme iptal edildi."
    exit 0
fi

# 3. Dinamik commit mesajını oluştur
COMMIT_MSG="vault backup: $DATE [$HOSTNAME] - $NUM_FILES dosya güncellendi"

# 4. Commit ve Push işlemlerini yürüt
echo "Farklar işleniyor..."
git commit -m "$COMMIT_MSG"

echo "Uzak depoya (Push) gönderiliyor..."
# Mevcut aktif branch adını otomatik bulur (master veya main fark etmez)
CURRENT_BRANCH=$(git branch --show-current)
git push origin "$CURRENT_BRANCH"

echo "✓ Yedekleme başarıyla tamamlandı!"
