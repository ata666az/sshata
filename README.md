# TENTANG
ini adalah script ssh dan X-ray vless vmess dan Trojan untuk di install di platform PaaS seperti railway render dan lainya yang support docker

# SPESIFIKASI
X-ray support udp ssh dropbear support udpgw ssh dropbear support payload emhaced os Ubuntu dan script node.js

# CARA INSTALL
pastikan kamu sudah punya akun github dan terlogin. klik logo pork di atas yg gambar kayak kaki 3 lalu klik create fork stelah script Ter copy ke githubmu login ke web PAas sperti railway instal script yg udah d fork tadi stelah di instal tambahkan 2 variabel di menu variabel 

1. **TOKEN** masukan nama variabel TOKEN dan value nya adalah token agro zerotrust

# UNTUK KONFIG SSH
* **USER DEFAULT:** dd
* **PASWORD DEFAULT:** dd
* # PENTING PENGATURAN PORT
* domain railway arahkan ke port 8081 untuk d jadikan ui
* tcp proxy railway arahkan ke port 8881
* port agro tunnel zerotrust arahkan ke port 8880


## blitz.cloud

Use the Docker image deployment path on blitz.cloud. This image intentionally runs as root inside the container because the panel creates/deletes Linux SSH accounts at runtime and starts Dropbear/Stunnel. The HTTP panel listens on `${PORT}` (default `8080`) and the Dockerfile declares `EXPOSE 8080`.


# DEPLOY BLITZ.CLOUD

- Gunakan Dockerfile yang disertakan dan build image `linux/amd64`.
- Port panel/UI: `8080` (`EXPOSE 8080` dan `PORT=8080`).
- Variabel utama tetap `TOKEN` untuk Cloudflare Zero Trust.
- Image sengaja menggunakan `USER root` karena fitur akun SSH membuat akun Linux melalui `useradd`/`chpasswd` dan menjalankan Dropbear pada port lokal 22.
- Bila aplikasi Blitz dibuat sebelum 25 September 2026 dan masih berjalan sebagai UID 1000, buka halaman aplikasi lalu lakukan **Restart** sekali supaya USER root dari image diterapkan.
- Direktori runtime aplikasi dipindahkan ke `/tmp/vmesssh` agar penulisan `config.json`, sertifikat Stunnel, banner, dan file runtime tidak bergantung pada `/app`.
