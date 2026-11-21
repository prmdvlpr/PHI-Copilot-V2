# PHI Daily Check v2 — SwiftUI capstone prototype

Proyek iPhone/iPad mandiri untuk mencoba alur mockup PHI. Kini tersedia target Watch terpisah dalam proyek yang sama. Koneksi/sinkronisasi iPhone–Watch belum diimplementasikan. Minimum iOS 17. Tidak membutuhkan package eksternal, API key, akun, atau HealthKit entitlement. Penjelasan Apple Intelligence opsional memakai model on-device jika tersedia; model perlu sudah diunduh oleh sistem.

## Tab iPhone dan iPad

- **Today** menampilkan hasil harian dan pilihan replay Demo Mode.
- **Ask PHI** menerima pertanyaan lanjutan tentang metrik, baseline, dan pemulihan. Jika Apple Intelligence aktif dan tersedia, model on-device memakai alat `getHealthMetrics` dan `analyzeRecovery`. Model mengisi `DailyCheckAnswer` dengan ringkasan, poin bukti, dan batas interpretasi. Jawaban Swift tersedia saat model dilewati atau gagal.
- **Insights** menampilkan perbandingan baseline, konteks aktivitas, dan penjelasan Apple Intelligence opsional.
- **Settings** memuat persetujuan akses metrik dan pengaturan Apple Intelligence.

Chat hanya disimpan dalam sesi app. Perubahan profil, hari replay, skenario, konteks, atau pilihan akses mengosongkan percakapan. Meter token adalah simulasi berdasarkan ukuran teks chat. Setelah batas simulasi tercapai, chat beralih ke jawaban Swift. **New chat** mereset meter. Semua tab memakai data simulasi dan tidak meminta akses Apple Health.

## Coba satu alur dulu

1. Buka **PHIDailyCheck.xcodeproj** di Xcode.
2. Pilih scheme **PHIDailyCheck**, lalu pilih iPhone Simulator yang tersedia (contoh: iPhone 17). Jika belum ada simulator runtime, unduh melalui Xcode Settings → Components/Platforms sesuai versi Xcode.
3. Tekan **⌘R**.
4. Pilih profil **Adi**, replay **hari 44**, biarkan resting HR dan HRV aktif, lalu **Continue with these choices**.
5. Verifikasi nilai sumber workshop: resting HR **65,6 bpm** dan HRV SDNN **42,6 ms**. Baseline dihitung dari 14 hari sebelumnya, tidak memakai nilai hari replay.
6. Tekan **Why am I seeing this?**. Pastikan penjelasan memakai evidence yang sama dan dua baseline terpisah.
7. Pilih **Hanna**: otomatis berpindah ke replay hari 30, dengan resting HR **52,0 bpm** dan SDNN **75,2 ms**. Tanggal rekaman ikut diperlihatkan.
8. Turunkan replay ke hari 10 untuk melihat fallback 9/14 hari. Menu skenario di kanan atas tetap menyediakan fixture buatan versi awal, termasuk 67/60 bpm dan 42/52 ms.

Tidak perlu memilih signing team untuk simulator. Untuk iPhone fisik, atur Team pada Signing & Capabilities, gunakan bundle identifier unik bila diperlukan, dan ikuti pairing/Developer Mode dari Xcode.

## Alur consent, bukti, dan fallback

- **Consent / Settings**: apa, mengapa, di mana. Pilihan data berlaku langsung. Ini persetujuan untuk fixture simulasi, bukan dialog izin HealthKit.
- **Insight + evidence / Hari ini**: nilai, baseline, jumlah hari valid, chart resting HR, bukti pendamping SDNN.
- **Insights**: perbandingan deterministik yang memakai evidence yang sama, serta konteks opsional pengguna.
- **Fallback**: riwayat kurang/data tidak terlihat menggantikan insight; HRV kosong tidak menghilangkan insight RHR; AI tidak tersedia tetap menggunakan aturan.

Menu slider di kanan atas memilih skenario demo dan dapat mengulang consent. Pilihan **Replay data workshop** menggunakan dataset kemarin. Skenario lain memakai fixture uji terpisah; nama profil tetap hanya alias demo.

| Skenario | Hasil yang diharapkan |
| --- | --- |
| Resting HR naik, HRV turun | RHR 67 vs 60 bpm; SDNN 42 vs 52 ms |
| Hari yang stabil | RHR 60 vs 60; SDNN 52 vs 52 |
| Resting HR ada, HRV belum ada | Insight resting HR saja; tidak mengarang HRV |
| Riwayat baru 9 hari | Belum cukup baseline 14 hari; tanpa kesimpulan perubahan |
| Data belum terlihat | Hasil kosong; tidak menebak izin ditolak |
| AI tidak tersedia | Panel fallback yang sengaja melewati model; angka/grafik/penjelasan aturan tetap berfungsi |

Di **Settings**, matikan HRV: angka/riwayat HRV hilang dari hasil. Matikan resting HR: insight utama dan penjelasan dibatasi walaupun HRV aktif. Pilihan tersimpan hanya selama sesi app; relaunch memulai consent baru.

## Batas prototype

- Mode workshop memakai salinan 120 record harian dari `Data/daily/daily_summary.csv`: 60 untuk alias Adi dari persona Tom, 60 untuk alias Hanna dari persona Maya. Resting HR/SDNN dan tanggal sumber dipertahankan; tidak ada inferensi umur, gender, kondisi kesehatan, atau kepemilikan data Adi/Hanna.
- Nama Adi/Hanna adalah **alias simulasi tim**, bukan pengukuran kalian. Pilihan persona hanya untuk membedakan cerita demo; atribut persona asli tidak dipindahkan ke identitas anggota tim.
- Tanggal sumber September–Oktober 2026; replay memperlakukan hari pilihan sebagai “hari ini”. Fixture skenario terpisah tetap memakai tanggal contoh 14 November 2026.
- Resource `WorkshopDailySamples.json` menyimpan nama source persona, disclaimer, hash CSV dan nilai sumber. Tidak memuat data mentah sensor atau label penyakit. Bila resource gagal dibaca, app menunjukkan hasil kosong/error, tidak mengganti dengan angka lain.
- Belum ada pembacaan/penulisan Apple Health, database PHI, backend, atau notifikasi. Apple Intelligence opsional kini diintegrasikan via FoundationModels. Skenario AI tidak tersedia sengaja melewati pemanggilan model; tidak mengubah pengaturan sistem.
- Model domain menganggap satu nilai ringkasan per metrik per hari. Seluruh fixture digambarkan sebagai sampel istirahat pagi; validasi konteks sampling HRV nyata belum dilakukan.
- Baseline dihitung per metrik dari **14 hari kalender sebelum hari ini**, minimum 14 nilai valid; hari ini dikecualikan. Median dan `spread = max(1.4826 × MAD, floor)`; floor RHR 1 bpm, HRV 2 ms. Rentang ilustrasi `median ± 1.5 × spread`.
- Minimum hari, floor dan rentang adalah pilihan pengajaran, bukan threshold medis atau reproduksi persis algoritme HealthCore workshop (yang memakai window/exclusion berbeda).
- Nilai nol, negatif dan non-finite ditolak. Hari duplikat tidak digabung; latest day duplikat menghasilkan data tidak tersedia. Importer nyata harus mendefinisikan agregasi, sumber, timezone, artefak dan deduplikasi sendiri.
- SDNN tidak disamakan dengan RMSSD atau skor Welltory. Tidak ada skor gabungan atau diagnosis. Konteks latihan tidak diperlakukan sebagai bukti penyebab.

## Struktur

- `PHIDailyCheckApp.swift`: entry point.
- `DailyCheckEngine.swift`: fixture, median/MAD, evidence, fallback availability dan penjelasan murni Swift.
- `DailyCheckViews.swift`: SwiftUI + Charts, consent, tabs, scenario menu dan empat pengalaman wajib.
- `Tests/EngineChecks.swift`: pemeriksaan logika yang bisa dijalankan tanpa simulator.
- `check-engine.sh`: compile dan jalankan pemeriksaan Foundation-only.
- `Resources/WorkshopDailySamples.json`: dua profil simulasi dari data workshop.

Jalankan pemeriksaan: `./check-engine.sh` dari folder ini. Hasil build dan batas verifikasi sesi pembuatan dicatat di `VALIDATION.md`.

Referensi API: [Apple — NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack), [Apple — Charts](https://developer.apple.com/documentation/charts).

## iPhone vs Apple Watch

Paket **PHIDailyCheck** memiliki target iPhone/iPad **PHIDailyCheck** dan target Watch mandiri **PHIDailyCheckWatch**, masing-masing dengan bundled sample data. Tidak ada pairing logic atau WatchConnectivity; profil, replay dan pilihan consent diatur terpisah di setiap app.

Pada folder workshop Day 2, **DigitalHealthLab** dan **HeadsUp** adalah proyek iPhone; **SensorDemos** dan **BreathCoach** adalah proyek Apple Watch terpisah. Mereka tidak otomatis menjadi companion PHIDailyCheck atau mengirim data kepadanya. Nama profil Adi/Hanna juga bukan akun, pairing perangkat, atau sinkronisasi antaranggota tim.

## Coba Apple Intelligence

1. Build/install ulang versi terbaru dari proyek yang sama ke iPhone. Binary yang sudah terpasang tidak berubah otomatis saat source diperbarui.
2. Di **Settings**, aktifkan **Apple Intelligence (optional)**. Aktifkan resting HR; HRV boleh aktif atau tidak.
3. Gunakan **Replay data workshop** → **Adi**, hari **44**, lalu buka **Insights**. Jangan memakai skenario “AI tidak tersedia” untuk mencoba generation.
4. Tekan **Buat penjelasan AI**. Status model diperiksa saat diminta; hasil diberi label Apple Intelligence/on-device dan bahasa output.
5. Cocokkan draf AI dengan fakta deterministik. Ubah profil/hari atau matikan HRV: hasil lama dibersihkan dan perlu dibuat ulang.

### Kebutuhan dan batasan

- Bagian AI membutuhkan **iOS 26+**, perangkat yang mendukung Apple Intelligence, fitur aktif di Settings, serta model yang tersedia. App utama tetap minimum iOS 17 dan memakai fallback pada OS/perangkat lama.
- Status mencakup perangkat tidak eligible, Apple Intelligence belum diaktifkan, model belum siap, dan unavailable lain. Kembali dari Settings akan menghapus hasil lama; tombol bisa dicoba lagi setelah status berubah.
- Seluruh UI, label grafik/aksesibilitas, tanggal, evidence, penjelasan aturan, status error, dan permintaan output Apple Intelligence kini memakai English. App memeriksa dukungan English sebelum meminta model; bila tidak didukung, fallback aturan tetap aktif. Tidak ada pilihan bahasa dalam versi ini. Unsupported language/guardrail/request error menghasilkan fallback, tanpa memaksa model.
- Menggunakan `SystemLanguageModel.default` dan session baru per permintaan. App tidak memakai Private Cloud Compute atau API eksternal. Hanya ringkasan evidence yang diizinkan, label sumber simulasi dan konteks pilihan tetap yang dimasukkan ke prompt—bukan seluruh dataset.
- Baseline, nilai, delta dan arah dihitung di Swift. AI diminta menulis ringkasan kualitatif tanpa angka. Output berangka digit, terlalu panjang, kosong, kata medis tertentu, atau penyebutan HRV saat HRV tak dipakai ditolak; penjelasan aturan tetap ada. Pemeriksaan ini heuristik: tidak membuktikan ketepatan arah, bahasa, atau semua klaim. Draf tetap perlu ditinjau pengguna.
- Membatalkan, mengubah profile/day/scenario/context/consent, atau berpindah status foreground/background membuang hasil/pending request. Timeout 25 detik mempertahankan fallback; respons telat tidak dapat menimpa state baru. Tidak ada multi-turn chat atau input bebas.
- Minimum Xcode untuk source FoundationModels ini: Xcode 26+, disarankan versi SDK yang dipakai tim. Source dikompilasi dengan Xcode 27.2 pada sesi pembuatan; runtime AI perangkat belum diuji.

Referensi: [Apple — Foundation Models generation](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models), [Apple — language support](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models).

## English interface update — 14 November 2026

App sekarang memakai English untuk semua empat bagian wajib, demo picker, consent, evidence, penjelasan aturan, fallback dan accessibility labels. Apple Intelligence diminta memberi output English. Date formatter memakai en_US; native SwiftUI controls memakai locale en. Model numerik/dataset dan aturan consent tidak diubah. Build/install ulang untuk menerapkan perubahan pada iPhone; binary yang sudah terpasang tidak otomatis diperbarui.

## Run the Apple Watch version

1. Open **PHIDailyCheck.xcodeproj**.
2. Choose the **PHIDailyCheckWatch** scheme, then an Apple Watch Simulator.
3. Press **⌘R**. If no Watch simulator runtime exists, install the needed runtime in Xcode Settings.
4. On the Watch: consent → Continue → one-screen resting HR/HRV summary. Open the iPhone app manually for evidence, charts, and explanations.
5. Tap the gear icon to open **Demo & access** and select Adi/Hanna, replay day, scenario or access choices.
6. Adi defaults to workshop day 44: 65.6 bpm and 42.6 ms. Hanna defaults to day 30: 52 bpm and 75.2 ms. Select day 10 to see the insufficient-history fallback.

For a physical Apple Watch, pair it with its iPhone using Apple's normal setup, enable the development settings requested by Xcode, select an appropriate Signing Team on the **PHIDailyCheckWatch** target, then run that scheme on your Watch. Use a unique bundle ID if required by signing. Installing the iPhone app alone does **not** install this standalone Watch target. This project does not configure automatic companion installation.

### Watch scope and limitations

- Native English SwiftUI, minimum watchOS 10. The everyday Watch experience is a one-screen summary; consent appears before first use and demo/access controls live in a settings sheet. Detailed evidence, charts and explanations live in the iPhone app. Small screens or large accessibility text may use a scroll fallback to preserve readability.
- Uses the exact same `DailyCheckEngine.swift` and `WorkshopDailySamples.json` as the phone app, referenced by both targets. No duplicated numeric algorithm, live heart-rate capture, HealthKit writes, or workout session.
- Standalone Watch app (`WKWatchOnly=YES`), not an embedded iPhone companion. Each app maintains its own session. Consent, profiles, replay and explanations are not transferred.
- The Watch shows a deterministic, qualitative summary status. Detailed rule-based and optional Apple Intelligence explanations remain in the iPhone app; no AI request runs on the Watch and no AI text is synced from iPhone.
- If a shared dataset resource cannot load, the Watch shows no-data fallback rather than fabricated samples.
- Simulator build verification does not establish physical-device installation, touch layout, or sensor behavior. See VALIDATION.md for actual checks.

## One-screen Watch summary update

Inspired by the circular battery display supplied by Adi, the Watch now shows a full status ring around the resting HR value, a short comparison label, and HRV SDNN below it. The ring is not a progress indicator or percentage health score. Green/amber/neutral states are paired with text.

After consent, normal use stays on this summary screen. Missing data or insufficient history replace its contents rather than opening a detailed flow. The gear opens a separate settings sheet; Review consent returns to the setup screen. “Details: open iPhone app” is a text instruction, not a handoff button. Open the phone app manually and select the same profile/day; device sessions remain independent. The four capstone experiences are provided across the product: consent and fallback remain on Watch, with full evidence and explanations on iPhone.
