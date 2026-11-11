# ComfyUI ROCm for Windows — ตัวติดตั้งคลิกเดียว (AMD + NVIDIA)

ติดตั้ง [ComfyUI](https://github.com/Comfy-Org/ComfyUI) บน Windows ให้ใช้การ์ด **AMD Radeon ผ่าน PyTorch ROCm** ได้เลย ไม่ต้องใช้ ZLUDA ไม่ต้องลง WSL
การ์ด NVIDIA ก็ใช้ได้ (ตัวติดตั้งเลือก CUDA ให้เอง) แยกออกมาจากโปรเจกต์ [Lumicos](https://github.com/Lumicos/lumicos)

## เคยโหลดไปติดตั้งแล้ว? อ่านตรงนี้ก่อน
ตัวติดตั้งรุ่นก่อนมีปัญหา **หน้า Manager ไม่ขึ้น** ในเครื่องที่ไม่ได้ลง Git (เกือบทุกเครื่อง) รุ่นนี้แก้แล้ว และอัปเดต ComfyUI เป็น v0.45.2 ได้ด้วย ทำตามนี้
1. กด **Code → Download ZIP** โหลดตัวติดตั้งชุดใหม่ แล้วแตกไฟล์ (ชุดเก่าลบทิ้งได้)
2. ปิดหน้าต่าง ComfyUI ให้หมด
3. เลือกทางใดทางหนึ่ง
   - **อยากได้ ComfyUI รุ่นใหม่ด้วย (แนะนำ):** ดับเบิลคลิก `Update ComfyUI.cmd` → ใส่โฟลเดอร์เดิม (เช่น `C:\ComfyUI` เว้นว่างได้ถ้าใช้ค่าเริ่มต้น) → พิมพ์ `Y` ตัวเก่าจะถูกสำรองไว้ใน `C:\ComfyUI\backups` ให้เอง
   - **แค่อยากให้ Manager ใช้ได้ ยังไม่อัปเดต:** ดับเบิลคลิก `Install ComfyUI.cmd` → ใส่โฟลเดอร์เดิม → พิมพ์ `Y` ตัวติดตั้งจะเติมเฉพาะส่วนที่ขาด โมเดลและงานเดิมอยู่ครบ
4. เปิดด้วย `C:\ComfyUI\Run ComfyUI.cmd` เหมือนเดิม ปุ่ม **Manager** จะอยู่แถบด้านบนของหน้า ComfyUI

อัปเดตแล้วมีปัญหา? ดับเบิลคลิก `Restore ComfyUI.cmd` เพื่อกลับไปใช้ตัวเก่า รายละเอียดดูหัวข้อ "อัปเดต ComfyUI" ด้านล่าง

## ใช้ยังไง (ติดตั้งครั้งแรก)
1. กด **Code → Download ZIP** แล้วแตกไฟล์
2. (ไม่บังคับ) ดับเบิลคลิก `Detect Only.cmd` เพื่อดูว่าการ์ดของคุณรองรับไหม ขั้นนี้ยังไม่ติดตั้งอะไร
3. ดับเบิลคลิก `Install ComfyUI.cmd` → เลือกโฟลเดอร์ (ค่าเริ่มต้น `C:\ComfyUI`) → พิมพ์ `Y`
4. เสร็จแล้วดับเบิลคลิก `C:\ComfyUI\Run ComfyUI.cmd` เบราว์เซอร์จะเปิด http://127.0.0.1:8188 ให้เอง

ถ้าเน็ตหลุดกลางทาง ให้รัน `Install ComfyUI.cmd` ซ้ำ แล้วเลือกโฟลเดอร์เดิม ตัวติดตั้งจะทำต่อจากจุดที่ค้างไว้

## การ์ดที่รองรับ
| การ์ด | สิ่งที่ติดตั้ง |
|---|---|
| AMD RX 9070 / 9070 XT / AI PRO R9700 | PyTorch 2.13 ROCm 10.0 (gfx1201) |
| AMD RX 9060 / 9060 XT | PyTorch 2.13 ROCm 10.0 (gfx1200) |
| AMD RX 7900 XT / XTX / GRE | PyTorch 2.13 ROCm 10.0 (gfx1100) |
| AMD RX 7700 / 7800 | PyTorch 2.13 ROCm 10.0 (gfx1101) |
| AMD RX 7600 / 7650 GRE | PyTorch 2.13 ROCm 10.0 (gfx1102) |
| AMD RX 6800 / 6900 / 6950 | PyTorch 2.13 ROCm 10.0 (gfx1030) |
| AMD RX 6700 / 6750 | PyTorch 2.13 ROCm 10.0 (gfx1031) |
| AMD RX 6600 / 6650 | PyTorch 2.13 ROCm 10.0 (gfx1032) |
| NVIDIA RTX 20/30/40/50 (ไดรเวอร์ CUDA 13+) | PyTorch 2.14.1 CUDA 13.0 |
| NVIDIA รุ่นเก่า / ไดรเวอร์ CUDA 12.4–12.x | PyTorch 2.6 CUDA 12.4 |

- **AMD:** อัปเดตไดรเวอร์ AMD Software: Adrenalin Edition เป็นรุ่นล่าสุดก่อนติดตั้ง ไม่ต้องลง HIP SDK แยก เพราะ ROCm มากับ PyTorch แล้ว
- การ์ดที่มี VRAM ต่ำกว่า 8 GB จะเปิดแบบ `--lowvram` ให้อัตโนมัติ
- การ์ดที่ยังไม่รองรับ เช่น RX 5000 / RX 500 / Intel Arc ตัวติดตั้งจะหยุดและบอกเหตุผล ไม่ติดตั้งครึ่ง ๆ กลาง ๆ

## ได้อะไรบ้าง
- ComfyUI **v0.45.2** (รุ่นทางการ ล็อก git commit ไว้ ถ้าไม่ตรงจะไม่ยอมติดตั้ง)
- ComfyUI-Manager (เปิดด้วย `--enable-manager`) ใช้ลง custom nodes ได้จากในหน้า ComfyUI **ไม่ต้องลง Git** (ใช้ pygit2 แทน)
- Python แยกของตัวเอง ทุกอย่างอยู่ในโฟลเดอร์เดียว ไม่แตะ Python หรือไฟล์ระบบของเครื่อง
- `Run ComfyUI.cmd` สำหรับเปิดในเครื่อง และ `Run ComfyUI (LAN).cmd` สำหรับเปิดจากมือถือหรือคอมเครื่องอื่นในบ้าน
- ไฟล์ที่ดาวน์โหลดตรวจ SHA-256 ก่อนใช้ (ส่วน ComfyUI ตรวจด้วย git commit) ส่วน PyTorch ดึงจาก repo ทางการของ AMD / PyTorch เท่านั้น

**โมเดลไม่ได้รวมมาให้** ให้ดาวน์โหลดเองแล้ววางตามโฟลเดอร์ `C:\ComfyUI\ComfyUI\models\` (`checkpoints`, `diffusion_models`, `text_encoders`, `vae`, `loras` …) หรือหาผ่าน Manager ก็ได้

## หน้า Manager ไม่ขึ้น (ติดตั้งไว้ก่อนหน้านี้)
ตัวติดตั้งรุ่นก่อนไม่ได้ลง pygit2 ไว้ ถ้าเครื่องไม่มี Git หน้า Manager จะโหลดไม่ขึ้น วิธีแก้เลือกอย่างใดอย่างหนึ่ง
- รัน `Install ComfyUI.cmd` ซ้ำ แล้วเลือกโฟลเดอร์เดิม (ได้ Manager ส่วน ComfyUI ยังเป็นรุ่นเดิม) หรือ
- รัน `Update ComfyUI.cmd` (ได้ทั้ง Manager และ ComfyUI รุ่นใหม่)

ถ้าเปิดผ่าน `Run ComfyUI (LAN).cmd` ตัว Manager จะไม่ยอมให้ลง custom node ซึ่งเป็นกฎความปลอดภัยของ Manager เอง ให้ลงผ่าน `Run ComfyUI.cmd` แทน

## อัปเดต ComfyUI (สำรองตัวเก่าไว้ให้)
1. ดาวน์โหลดตัวติดตั้งชุดใหม่ (Code → Download ZIP) แล้วแตกไฟล์
2. ปิด ComfyUI ก่อน แล้วดับเบิลคลิก `Update ComfyUI.cmd` → เลือกโฟลเดอร์เดิม → พิมพ์ `Y`
3. ตัวอัปเดตจะติดตั้งตัวใหม่แยกไว้ แล้วทดสอบการ์ดจอให้ผ่านก่อน จึงค่อยสลับไปใช้ ถ้าไม่ผ่าน ตัวเดิมยังใช้ได้เหมือนเดิม
4. ตัวเก่า (โค้ด, Python, custom_nodes) เก็บไว้ที่ `C:\ComfyUI\backups\ComfyUI-<รุ่น>-<วันเวลา>` ส่วน `models`, `input`, `output`, `user` (settings, workflows) ย้ายมาใช้กับตัวใหม่ ไม่คัดลอกซ้ำ
5. ถ้าตัวใหม่มีปัญหา ดับเบิลคลิก `Restore ComfyUI.cmd` เพื่อกลับไปใช้ตัวเก่า ตัวที่ถอดออกจะเก็บไว้ใน `backups` ด้วย จึงสลับไปกลับได้

ตัวสำรองแต่ละชุดกินพื้นที่หลาย GB ใช้ตัวใหม่จนมั่นใจแล้วลบโฟลเดอร์ใน `backups` ทิ้งได้เลย

**ถอนการติดตั้ง:** ลบโฟลเดอร์ `C:\ComfyUI` ทิ้งทั้งโฟลเดอร์ได้เลย

## สถานะการทดสอบ (บอกตรง ๆ)
- **NVIDIA:** ทดสอบติดตั้งจริงครบทุกขั้นบน RTX 5060 Ti 16 GB (Windows 11)
- **AMD:** ชุด PyTorch 2.13 + ROCm 10.0 ตัวนี้ผู้เขียนใช้จริงบน RX 6600 ทั้งทำรูปและวิดีโอ แต่ตอนนี้ไม่มีการ์ด AMD แล้ว ตัวติดตั้งตัวนี้จึง**ยังไม่ได้ลองบนการ์ด AMD จริง** ถ้าใช้ได้หรือติดปัญหา ฝากเปิด Issue พร้อมผลจาก `Detect Only.cmd` และข้อความ error ด้วย จะช่วยได้มาก

---

## English
One-click installer for ComfyUI on Windows with **AMD Radeon via PyTorch ROCm** (no ZLUDA, no WSL), also handles NVIDIA (CUDA). Download the ZIP, run `Install ComfyUI.cmd`, then `Run ComfyUI.cmd`.

- AMD RX 6600–6950, 7600–7900, 9060/9070 and AI PRO R9700 → `torch 2.13.0+rocm10.0.0` with the matching `gfx` device wheel from `stable.repo.amd.com`.
- NVIDIA with a CUDA 13 driver → `torch 2.14.1+cu130`. Older cards or drivers → `torch 2.6.0+cu124`.
- ComfyUI v0.45.2 (pinned by git commit, fetched with pygit2) plus the built-in ComfyUI-Manager, which uses pygit2 so Git does not need to be installed. Other downloads are SHA-256 pinned.
- `Update ComfyUI.cmd` builds the new version beside the old one, GPU-tests it, then swaps it in and keeps the old code, Python env and custom_nodes under `backups\`. `Restore ComfyUI.cmd` swaps back. Everything stays in one folder: delete the folder to uninstall.
- Re-run the installer on the same folder to resume after a failure. `Detect Only.cmd` shows the plan without installing.
- Tested end to end on an RTX 5060 Ti. The ROCm package set is the one the author ran daily on an RX 6600, but this installer has not yet run on an AMD card. Reports are welcome in Issues.

MIT licence for the installer scripts. ComfyUI is GPL-3.0; PyTorch and the ROCm wheels keep their own licences.
