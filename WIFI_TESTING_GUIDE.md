# Panduan Testing Sistem WiFi Attendance

## ✅ Checklist Testing

### 1. Setup Awal (Admin)
- [ ] Login sebagai Admin
- [ ] Tambahkan WiFi network di "Kelola WiFi Networks"
- [ ] Pastikan SSID dan BSSID benar (format BSSID: `aa:bb:cc:dd:ee:ff` lowercase)

### 2. Test Positive (Berhasil)
- [ ] Login sebagai Employee
- [ ] Hubungkan device ke WiFi kantor yang sudah terdaftar
- [ ] Buka halaman Absensi
- [ ] Pastikan SSID dan BSSID terdeteksi (hijau)
- [ ] Tekan "Check-in" → Harus berhasil ✅
- [ ] Verifikasi log muncul di Dashboard Admin

### 3. Test Negative (Ditolak)
- [ ] Hubungkan device ke WiFi lain (tidak terdaftar)
- [ ] Atau gunakan mobile data
- [ ] Coba Check-in → Harus ditolak dengan pesan error ❌

### 4. Test Manual Input
- [ ] Putuskan WiFi
- [ ] Di halaman Absensi, tekan "Masukkan Manual"
- [ ] Masukkan SSID dan BSSID yang benar
- [ ] Tekan "Terapkan"
- [ ] Tekan "Check-in" → Harus berhasil ✅

### 5. Test Verifikasi Data
- [ ] Cek di Firebase Console → Collection `attendanceLogs`
- [ ] Pastikan field tersimpan:
  - `wifiSsid` ✅
  - `wifiBssid` (lowercase) ✅
  - `checkIn` timestamp ✅
  - `userId` ✅

## 🔍 Troubleshooting

### WiFi tidak terdeteksi otomatis
- **Masalah**: Auto-detect tidak tersedia (platform limitation)
- **Solusi**: Gunakan "Masukkan Manual" atau implement platform channel untuk native WiFi detection

### Check-in ditolak meski WiFi benar
- **Masalah**: BSSID tidak match (case sensitivity atau format berbeda)
- **Solusi**: 
  - Pastikan BSSID di Firestore lowercase (contoh: `aa:bb:cc:dd:ee:ff`)
  - Pastikan BSSID yang diinput juga lowercase
  - Cek dengan tepat MAC address router

### Error "Perangkat berbeda"
- **Masalah**: Device binding aktif
- **Solusi**: Fitur ini sudah dinonaktifkan, tapi pastikan `deviceId` tersimpan dengan benar

## 📝 Catatan Penting

1. **BSSID harus lowercase**: Sistem menormalisasi ke lowercase untuk konsistensi
2. **SSID case-sensitive**: Pastikan SSID sama persis dengan yang terdaftar
3. **Web Platform**: Auto-detect WiFi tidak tersedia di web, harus manual input
4. **Mobile Platform**: Perlu permission `ACCESS_WIFI_STATE` (sudah ada di AndroidManifest.xml)


