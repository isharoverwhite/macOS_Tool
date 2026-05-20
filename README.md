<p align="center">
  <img src="https://img.shields.io/badge/version-1.1-00BFFF?style=for-the-badge&logo=apple&logoColor=white">
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey?style=for-the-badge&logo=apple">
  <img src="https://img.shields.io/badge/shell-bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=for-the-badge">
</p>

<h1 align="center">🔒 macOS Tool Collection</h1>
<h3 align="center">Bộ công cụ dòng lệnh chuyên dụng cho macOS — được xây dựng bởi developer, dành cho developer</h3>

<p align="center">
  <strong>Giải quyết những việc lặt vặt nhưng quan trọng mà macOS chưa làm tốt — trực tiếp từ terminal.</strong>
</p>

---

## 📖 Giới thiệu

**macOS Tool Collection** là tập hợp các công cụ dòng lệnh nhỏ gọn, được xây dựng để giải quyết các vấn đề cụ thể trong môi trường phát triển trên macOS. Mỗi công cụ hoạt động độc lập, không phụ thuộc vào nhau, và có thể cài đặt riêng lẻ hoặc cùng nhau chỉ bằng một lệnh.

> 💡 **Triết lý thiết kế:** Mỗi công cụ giải quyết đúng một vấn đề, làm tốt một việc — không bloat, không dependency nặng nề.

---

## 🛡️ Công cụ hiện có

### 1. Sandbox Shell Manager (`sbox`)

Quản lý môi trường sandbox macOS bằng TUI — cách ly ứng dụng khỏi hệ thống mà không cần máy ảo.

<table>
<tr>
<td width="50%">

**❌ Vấn đề cũ**

- Chạy script lạ → lo ngại viết vào `/usr`, `/bin`
- Không có cách nào cách ly network dễ dàng
- `sandbox-exec` quá phức tạp, không có GUI
- Không biết ứng dụng đang access file nào
- Mỗi project dùng chung storage → lẫn lộn dữ liệu

</td>
<td width="50%">

**✅ Giải pháp với sbox**

- TUI đẹp để tạo và quản lý sandbox profile
- Toggle network IN/OUT, filesystem, USB chỉ bằng phím
- Profile template sẵn: web-dev, data-science, minimal
- Session log ghi lại thời gian, profile, exit code
- Mỗi project có workspace disk riêng (DMG) trong thư mục project

</td>
</tr>
</table>

---

### 2. NPM Package Manager TUI (`npkg`)

Quản lý NPM packages bằng TUI — xem, cập nhật, cài đặt và gỡ packages mà không cần nhớ lệnh.

<table>
<tr>
<td width="50%">

**❌ Vấn đề cũ**

- `npm list -g --depth=0` ra danh sách dài, khó đọc
- Phải chạy `npm outdated` riêng để biết cái nào cũ
- Update từng package: phải nhớ tên rồi gõ tay
- Không biết package nào là `dep`, cái nào là `devDep`
- Xóa nhầm package vì không có bước confirm

</td>
<td width="50%">

**✅ Giải pháp với npkg**

- Bảng TUI hiển thị đầy đủ: tên, version cài, version mới, loại, trạng thái
- Highlight package nào `OUTDATED` bằng màu vàng ngay lập tức
- Update một package (phím `U`) hoặc tất cả cùng lúc (phím `A`)
- Toggle giữa global packages và project packages bằng `G` / `P`
- Multi-select bằng `SPACE` để xóa nhiều packages một lần

</td>
</tr>
</table>

---

## ✨ Tính năng của Sandbox Shell Manager

<table>
<tr>
<td width="50%">

**🎛️ TUI Dashboard**
- Bảng điều khiển tương tác trong terminal
- Điều hướng bằng phím mũi tên
- Hiển thị trạng thái workspace disk theo project

**🔧 Tạo profile linh hoạt**
- Wizard cấu hình từng quyền: network, filesystem, USB, IPC
- Tự scan thư mục Home và cổng USB/Serial
- Hỗ trợ thêm custom path thủ công

**📦 Template profiles sẵn có**
- `web-dev`: cho phép network outbound, block system write
- `data-science`: không có network, truy cập Documents/Downloads
- `minimal`: cách ly tối đa, chỉ MNT volume

</td>
<td width="50%">

**💾 Workspace Disk theo project**
- DMG nằm trong thư mục project, đặt tên theo project
- Tự động mount/unmount khi vào/ra sandbox
- Chọn dung lượng: 512MB, 1GB, 2GB

**🔐 Khóa profile**
- Lock profile để tránh xóa nhầm
- Toggle lock/unlock bằng phím `K`

**📋 Session Logging**
- Ghi lại thời điểm launch, profile, project, duration, exit code
- Log viewer tích hợp trong TUI (phím `L`)

**⚡ CLI Quick-launch**
- `sbox myprofile` — vào sandbox ngay, bỏ qua TUI
- `sbox --run myprofile "npm start"` — chạy lệnh rồi thoát

</td>
</tr>
</table>

---

## ✨ Tính năng của NPM Package Manager TUI

<table>
<tr>
<td width="50%">

**🎛️ TUI Dashboard**
- Bảng điều khiển đầy đủ: ID, tên package, version cài, version mới nhất, loại, trạng thái
- Điều hướng bằng phím mũi tên
- Phân trang tự động khi có nhiều package

**🔄 Quản lý cập nhật**
- Tự động so sánh semver để phát hiện package lỗi thời
- Update package đang chọn bằng phím `U`
- Update tất cả outdated packages một lần bằng phím `A`

**📦 Chế độ Project / Global**
- Tự động nhận diện `package.json` khi mở
- Phân biệt `dep` (dependency) và `dev` (devDependency)
- Chuyển giữa Global và Project chỉ bằng phím `G` / `P`

</td>
<td width="50%">

**🗑️ Xóa package an toàn**
- Confirm trước khi xóa để tránh nhầm
- Multi-select bằng `SPACE`: đánh dấu nhiều package, xóa một lần
- Hiển thị danh sách sẽ bị xóa trước khi confirm

**📥 Cài đặt package**
- Tìm kiếm và cài package mới trực tiếp từ TUI
- Chọn loại: `dependency` hay `devDependency`
- Hỗ trợ cú pháp `name@version`

**🔁 Reload nhanh**
- Nhấn `R` để refresh toàn bộ danh sách
- Tự động reload sau mỗi thao tác cài/xóa/update

</td>
</tr>
</table>

---

## 🖥️ Giao diện Sandbox Shell Manager

```mermaid
block-beta
  columns 3
  header["┌── MAC OS HARDENED SANDBOX MANAGER ──┐"]:3
  status["▶ SYSTEM STATUS\nProject: ~/GitHub/MyProject\n[OK] Workspace Disk: Mounted → /Volumes/MyProject"]:3
  col1["▶ SECURITY PROFILES\n┌────┬──────────────────┬──────┬───────────────────┐\n│ ID │ PROFILE NAME     │ LOCK │ DESCRIPTION       │\n│ ➜0 │ web_dev.sb       │      │ Template: web-dev │\n│  1 │ data_science.sb  │ [L]  │ Template: data-sc │\n│  2 │ minimal.sb       │      │ Template: minimal │\n└────┴──────────────────┴──────┴───────────────────┘"]:3
  footer["[C] Create | [T] Template | [W] Workspace | [K] Lock | [D] Delete | [L] Logs | [ENTER] Launch"]:3
```

---

## 🖥️ Giao diện NPM Package Manager TUI

```mermaid
block-beta
  columns 3
  header["┌────────────────── NPM PACKAGE MANAGER · npkg ──────────────────┐"]:3
  tabs["[G] Global          [P] Project  ~/my-app  ✔ my-app"]:3
  table["▶ PACKAGES  12 installed  3 outdated\n┌──────┬───┬────────────────────────┬──────────┬──────────┬──────┬──────────┐\n│  ID  │ ● │ PACKAGE                │ INSTLD   │ LATEST   │ TYPE │ STATUS   │\n│ ➜ 0  │   │ axios                  │ 1.6.0    │ 1.7.2    │ dep  │ OUTDATED │\n│   1  │   │ eslint                 │ 9.0.0    │ 9.0.0    │ dev  │ OK       │\n│ * 2  │ * │ lodash                 │ 4.17.21  │ 4.17.21  │ dep  │ OK       │\n└──────┴───┴────────────────────────┴──────────┴──────────┴──────┴──────────┘"]:3
  footer["[↑↓] Nav  [SPACE] Mark  [U] Update sel  [A] Update all  [I] Install\n[D] Delete  [G] Global  [P] Project  [R] Reload  [CTRL+C] Exit"]:3
```

---

## 📦 Cài đặt

### Cách 1: Script cài đặt tự động (Khuyến nghị)

```bash
git clone https://github.com/isharoverwhite/macOS_Tool.git
cd macOS_Tool
chmod +x install.sh
./install.sh
```

### Cách 2: Chỉ cài một tool cụ thể

```bash
./install.sh --only sandbox   # Chỉ cài Sandbox Manager
./install.sh --only npkg      # Chỉ cài NPM Package Manager
./install.sh --only etool     # Chỉ cài etool updater
```

### Cách 3: Cài thủ công

```bash
# Sandbox Manager
cp sandbox-shell.sh ~/.local/bin/sbox && chmod +x ~/.local/bin/sbox

# NPM Package Manager
cp npkg.sh ~/.local/bin/npkg && chmod +x ~/.local/bin/npkg
```

### Yêu cầu hệ thống

| Công cụ | Yêu cầu | Ghi chú |
|---------|---------|---------|
| **sbox** | macOS 12+, `zsh`, `hdiutil`, `sandbox-exec` | Có sẵn trên macOS |
| **npkg** | macOS 12+, `npm`, `node`, `python3` | `npm` + `node` cài qua [nodejs.org](https://nodejs.org) |
| **etool** | macOS 12+, `curl` | Có sẵn trên macOS |

---

## 🚀 Quy trình sử dụng — Sandbox Manager

```mermaid
flowchart TD
    A[📂 cd vào thư mục project] --> B[⌨️ Gõ `sbox`]
    B --> C{Có workspace disk?}
    C -->|Không| D[Nhấn W để tạo DMG]
    D --> E[Chọn dung lượng: 512MB / 1GB / 2GB]
    E --> F[DMG được tạo trong project folder]
    C -->|Có| G[Nhấn C hoặc T để tạo profile]
    F --> G
    G --> H{Chọn cách tạo profile}
    H -->|Template| I[Chọn: web-dev / data-science / minimal]
    H -->|Tự tạo| J[Wizard cấu hình quyền từng mục]
    I --> K[Profile .sb được lưu vào ~/.sandbox/]
    J --> K
    K --> L[Chọn profile → Nhấn ENTER]
    L --> M[Workspace disk auto-mount]
    M --> N[🔒 Vào sandbox shell]
    N --> O[Làm việc trong môi trường cách ly]
    O --> P[Exit shell]
    P --> Q[Workspace disk auto-unmount]
    Q --> R[Session log được ghi]
```

---

## 🚀 Quy trình sử dụng — NPM Package Manager

```mermaid
flowchart TD
    A[📂 cd vào thư mục project] --> B[⌨️ Gõ `npkg`]
    B --> C{Có package.json?}
    C -->|Có| D[Chế độ Project: hiển thị dep + devDep]
    C -->|Không| E[Chế độ Global: hiển thị global packages]
    D --> F[Xem bảng packages]
    E --> F
    F --> G{Thao tác}
    G -->|U| H[Update package đang chọn]
    G -->|A| I[Update tất cả outdated]
    G -->|I| J[Cài package mới]
    G -->|SPACE + D| K[Multi-select rồi xóa]
    G -->|G / P| L[Chuyển chế độ Global/Project]
    H --> M[Reload danh sách]
    I --> M
    J --> M
    K --> M
```

---

## 🗂️ Cấu trúc project

```mermaid
graph TD
    root["📁 macOS_Tool/"]
    root --> sbox["🔒 sandbox-shell.sh\n(Sandbox Manager → sbox)"]
    root --> npkg["📦 npkg.sh\n(NPM Package Manager → npkg)"]
    root --> install["⚙️ install.sh\n(Cài đặt tất cả tools)"]
    root --> readme["📖 README.md"]

    sbox --> cfg["~/.sandbox/\n(profiles *.sb)"]
    sbox --> log["~/.sandbox/.sandbox_log\n(session log)"]
    sbox --> dmg["~/project/<name>.dmg\n(workspace disk per project)"]
    dmg --> mnt["/Volumes/<name>\n(auto-mounted khi launch)"]

    npkg --> npm["npm list / npm outdated\n(data source)"]
    npkg --> tmp["/tmp/npkg_*/\n(temp files, auto-cleaned)"]
```

---

## ⌨️ Phím tắt — Sandbox Shell Manager

| Phím | Chức năng |
|------|-----------|
| `↑` / `↓` | Di chuyển giữa các profile |
| `ENTER` | Launch sandbox với profile được chọn |
| `C` | Tạo profile mới bằng wizard |
| `T` | Tạo profile từ template có sẵn |
| `W` | Tạo workspace disk cho project hiện tại |
| `K` | Toggle lock/unlock profile |
| `D` | Xóa profile (không xóa được nếu đang locked) |
| `L` | Xem session log |
| `CTRL+C` | Thoát |

---

## ⌨️ Phím tắt — NPM Package Manager TUI

| Phím | Chức năng |
|------|-----------|
| `↑` / `↓` | Di chuyển giữa các package |
| `SPACE` | Đánh dấu / bỏ đánh dấu package (multi-select) |
| `U` | Update package đang chọn lên latest |
| `A` | Update tất cả package đang outdated |
| `I` | Cài package mới |
| `D` | Xóa package đang chọn (hoặc tất cả đã marked) |
| `G` | Chuyển sang chế độ Global packages |
| `P` | Chuyển sang chế độ Project packages |
| `R` | Reload danh sách |
| `CTRL+C` | Thoát |

---

## 🔧 Công nghệ sử dụng

| Công nghệ | Mục đích |
|-----------|---------|
| `bash` | Ngôn ngữ viết script chính |
| `sandbox-exec` | Engine thực thi sandbox Apple Sandbox Profile |
| `hdiutil` | Tạo và quản lý DMG disk image |
| `npm` | Nguồn dữ liệu package cho `npkg` |
| `python3` | Parse JSON output từ `npm list` / `npm outdated` |
| `tput` + ANSI | Vẽ TUI trong terminal |
| Apple Sandbox Profile (`.sb`) | Định nghĩa luật cách ly: network, filesystem, process |

---

## 📋 Cấu hình

| File | Công cụ | Vị trí | Mô tả |
|------|---------|--------|-------|
| Profiles | `sbox` | `~/.sandbox/*.sb` | Các security profile |
| Session log | `sbox` | `~/.sandbox/.sandbox_log` | Log toàn bộ session |
| Workspace disk | `sbox` | `<project_dir>/<name>.dmg` | DMG riêng của từng project |
| Temp files | `npkg` | `/tmp/npkg_*/` | Tự xóa khi thoát |

---

## 🗺️ Roadmap

- [ ] Giao diện xem nội dung profile `.sb` trong TUI
- [ ] Export/import profile để chia sẻ giữa các máy
- [ ] `npkg`: hỗ trợ `yarn` và `pnpm` ngoài `npm`
- [ ] `npkg`: filter/search package theo tên trong TUI
- [ ] Hỗ trợ `fish` shell ngoài `zsh`
- [ ] Notification khi sandbox bị vi phạm policy

---

## 👤 Người dùng phù hợp

- Developer macOS muốn chạy code lạ an toàn
- Người nghiên cứu bảo mật cần môi trường cách ly nhanh
- Developer làm việc với nhiều project cùng lúc, cần tách biệt storage
- Frontend / Node.js developer mệt mỏi với việc gõ lệnh `npm` thủ công

---

<br>

<p align="center">
  <sub>🛠️ Được xây dựng với ❤️ bởi <strong>Dinh Trung Kien</strong> | © 2026</sub>
</p>

<p align="center">
  <sub>⭐ Nếu công cụ này hữu ích, hãy star repo để ủng hộ!</sub>
</p>
