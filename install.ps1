param([string]$Root,[int]$GpuIndex=-1,[switch]$Yes,[switch]$DetectOnly,[string]$HardwareFile)
# ComfyUI for Windows: AMD (PyTorch ROCm) or NVIDIA (CUDA), one folder, nothing installed system-wide.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$kit=$PSScriptRoot
$pins=Get-Content -LiteralPath (Join-Path $kit 'pins.json') -Raw | ConvertFrom-Json
function Say($text,$color='Gray'){Write-Host $text -ForegroundColor $color}
function Fail($text){Say "`n[หยุด] $text" Red;exit 1}

Say "ComfyUI Installer for Windows (AMD ROCm / NVIDIA CUDA) - ComfyUI $($pins.comfyui.version)" Cyan

# 1) Hardware
$hwFile=Join-Path $env:TEMP 'comfyui-installer-hardware.json'
if($HardwareFile){$hwFile=$HardwareFile}else{& (Join-Path $kit 'src\detect.ps1') -OutputPath $hwFile}
$hw=Get-Content -LiteralPath $hwFile -Raw | ConvertFrom-Json
Say ("CPU: {0}`nRAM: {1} GiB`nWindows: {2} (build {3})" -f $hw.cpu,$hw.ramGiB,$hw.os,$hw.build)
$gpus=@($hw.gpus)
for($i=0;$i -lt $gpus.Count;$i++){Say ("GPU {0}: {1}  VRAM {2} GiB  driver {3}" -f $i,$gpus[$i].name,$gpus[$i].vramGiB,$gpus[$i].driver)}
if($hw.arch -ne 'X64' -or $hw.build -lt 19045){Fail 'ต้องใช้ Windows 10 22H2 หรือ Windows 11 แบบ 64 บิต'}
if(-not $gpus.Count){Fail 'ไม่พบการ์ดจอ'}

if($GpuIndex -lt 0){
 $best=-1;$score=-1
 for($i=0;$i -lt $gpus.Count;$i++){$s=[double]($gpus[$i].vramGiB)+$(if($gpus[$i].name -match 'NVIDIA|Radeon RX|Radeon AI PRO'){100}else{0});if($s -gt $score){$score=$s;$best=$i}}
 $GpuIndex=$best
 if($gpus.Count -gt 1 -and -not $Yes -and -not $DetectOnly){$a=Read-Host "เลือกการ์ดจอ (เว้นว่าง = $GpuIndex)";if($a){$GpuIndex=[int]$a}}
}
if($GpuIndex -ge $gpus.Count){Fail 'เลขการ์ดจอไม่ถูกต้อง'}
$gpu=$gpus[$GpuIndex]

# 2) Which PyTorch
$kind=$null;$target=$null;$why=''
if($gpu.name -match 'NVIDIA'){
 $cuda=[double]$(if($hw.cudaMax){$hw.cudaMax}else{0})
 $old=$gpu.name -match 'GTX\s*(9\d\d|10\d\d)|TITAN (X|V)|Quadro (M|P)'
 if(-not $old -and $cuda -ge 13.0){$kind='cu130'}
 elseif($cuda -ge 12.4 -and $gpu.name -notmatch 'RTX\s*50\d\d'){$kind='cu124'}
 else{$why='ไดรเวอร์ NVIDIA เก่าเกินไป (CUDA ' + $cuda + ') อัปเดตไดรเวอร์ล่าสุดจาก nvidia.com แล้วลองใหม่'}
}elseif($gpu.name -match 'AMD|Radeon'){
 $map=@(
  @('RX\s*9070|AI PRO R9700','gfx1201'),@('RX\s*9060','gfx1200'),
  @('RX\s*7900','gfx1100'),@('RX\s*(7700|7800)','gfx1101'),@('RX\s*76[05]0','gfx1102'),
  @('RX\s*(6800|6900|6950)','gfx1030'),@('RX\s*(6700|6750)','gfx1031'),@('RX\s*(6600|6650)','gfx1032')
 )
 foreach($m in $map){if($gpu.name -match $m[0]){$target=$m[1];break}}
 if($target){$kind='rocm'}else{$why='การ์ด AMD รุ่นนี้ยังไม่อยู่ในรายการที่รองรับ (RX 6600-6950, RX 7600-7900, RX 9060/9070) แจ้งชื่อรุ่นมาได้ที่หน้า Issues'}
}else{$why='รองรับเฉพาะการ์ด AMD Radeon RX 6000/7000/9000 และ NVIDIA'}
if(-not $kind){Fail $why}
$t=$pins.torch.$kind
$vram=[double]$(if($gpu.vramGiB){$gpu.vramGiB}else{0})
$low=$vram -gt 0 -and $vram -lt 7.5
Say ("`nแผนติดตั้ง: {0} -> PyTorch {1}{2}, Python {3}" -f $gpu.name,$t.torch,$(if($target){" ($target)"}else{''}),$t.python) Green
if($low){Say 'การ์ดมี VRAM น้อยกว่า 8 GB: จะเปิด ComfyUI แบบ --lowvram (ช้าลงแต่ทำงานได้)' Yellow}
if($DetectOnly){Say "`nตรวจอย่างเดียว ไม่ได้ติดตั้งอะไร" Cyan;exit 0}

# 3) Folder
if(-not $Root){$default='C:\ComfyUI';if($Yes){$Root=$default}else{$a=Read-Host "โฟลเดอร์ติดตั้ง [เว้นว่าง = $default]";$Root=if($a){$a}else{$default}}}
$Root=[IO.Path]::GetFullPath($Root.Trim().Trim('"'))
if($Root -match '[^\x20-\x7E]'){Fail 'ชื่อโฟลเดอร์ต้องเป็นภาษาอังกฤษล้วน (Python บางตัวพังกับชื่อภาษาไทย) เช่น C:\ComfyUI'}
if($Root -match '[%&|<>^!"]' -or [IO.Path]::GetPathRoot($Root) -eq $Root){Fail 'เลือกโฟลเดอร์ย่อย เช่น C:\ComfyUI'}
$marker=Join-Path $Root 'installer-state.json'
if((Test-Path -LiteralPath $Root) -and @(Get-ChildItem -LiteralPath $Root -Force).Count -and -not (Test-Path -LiteralPath $marker)){Fail "โฟลเดอร์ $Root มีไฟล์อื่นอยู่แล้ว เลือกโฟลเดอร์ใหม่ที่ว่าง"}
$drive=Get-PSDrive -Name $Root.Substring(0,1) -ErrorAction SilentlyContinue
if($drive -and $drive.Free -lt 20GB){Say ("พื้นที่ว่างไดรฟ์ {0}: เหลือ {1:N1} GB (แนะนำอย่างน้อย 20 GB ไม่รวมโมเดล)" -f $drive.Name,($drive.Free/1GB)) Yellow}
if(-not $Yes){$a=Read-Host "ติดตั้งลง $Root ? (Y/N)";if($a -notmatch '^[yY]'){exit 0}}
New-Item -ItemType Directory -Force -Path $Root | Out-Null

$state=if(Test-Path -LiteralPath $marker){Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json}else{$null}
if($state -and $state.kind -ne $kind){Fail 'โฟลเดอร์นี้เคยติดตั้งสำหรับการ์ดอีกแบบ ใช้โฟลเดอร์ใหม่'}
$done=@{};if($state){foreach($s in $state.done){$done[$s]=$true}}
function Save-State($extra){$o=[ordered]@{kind=$kind;target=$target;gpu=$gpu.name;comfyui=$pins.comfyui.version;torch=$t.torch;done=@($done.Keys)};if($extra){foreach($k in $extra.Keys){$o[$k]=$extra[$k]}};[IO.File]::WriteAllText($marker,($o|ConvertTo-Json),(New-Object Text.UTF8Encoding $false))}
function Step($name,$label,[scriptblock]$body){if($done[$name]){Say "ข้าม (ทำแล้ว): $label" DarkGray;return};Say "`n== $label" Cyan;& $body;$done[$name]=$true;Save-State}
function Get-Pinned($item,$file){
 if(Test-Path -LiteralPath $file){if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -eq $item.sha256){return};Remove-Item -LiteralPath $file -Force}
 $part="$file.part";Invoke-WebRequest -UseBasicParsing -Uri $item.url -OutFile $part
 if((Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash.ToLower() -ne $item.sha256){Remove-Item -LiteralPath $part -Force;Fail "ไฟล์ที่ดาวน์โหลดไม่ตรง checksum: $($item.url)"}
 Move-Item -LiteralPath $part -Destination $file -Force
}
function Unzip-Flat($zip,$dest,$expect){
 $tmp="$dest.extract";if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Recurse -Force}
 & (Join-Path $kit 'src\extract.ps1') -Archive $zip -Destination $tmp
 $inner=if(Test-Path -LiteralPath (Join-Path $tmp $expect)){$tmp}else{(Get-ChildItem -LiteralPath $tmp -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName $expect)} | Select-Object -First 1).FullName}
 if(-not $inner){Fail "ไฟล์ zip ไม่มี $expect"}
 New-Item -ItemType Directory -Force -Path $dest | Out-Null
 Get-ChildItem -LiteralPath $inner -Force | ForEach-Object {Move-Item -LiteralPath $_.FullName -Destination $dest -Force}
 Remove-Item -LiteralPath $tmp -Recurse -Force
}
function Exe($file,[string[]]$arguments){& $file @arguments;if($LASTEXITCODE -ne 0){Fail ("คำสั่งล้มเหลว ({0}): {1} {2}`nรันตัวติดตั้งซ้ำด้วยโฟลเดอร์เดิมเพื่อทำต่อจากจุดที่ค้าง" -f $LASTEXITCODE,(Split-Path $file -Leaf),($arguments -join ' '))}}

$dl=Join-Path $Root '.downloads';New-Item -ItemType Directory -Force -Path $dl | Out-Null
$uv=Join-Path $Root 'runtime\uv\uv.exe'
$comfy=Join-Path $Root 'ComfyUI'
$py=Join-Path $comfy '.venv\Scripts\python.exe'
# Everything uv touches stays inside the install folder: delete the folder = uninstall.
$env:UV_PYTHON_INSTALL_DIR=Join-Path $Root 'runtime\python'
$env:UV_CACHE_DIR=Join-Path $Root '.uv-cache'
$env:UV_LINK_MODE='copy'
$env:UV_HTTP_TIMEOUT='600'

Step 'uv' 'ดาวน์โหลด uv (ตัวจัดการ Python)' {Get-Pinned $pins.uv (Join-Path $dl 'uv.zip');Unzip-Flat (Join-Path $dl 'uv.zip') (Join-Path $Root 'runtime\uv') 'uv.exe'}
Step 'comfyui' "ดาวน์โหลด ComfyUI $($pins.comfyui.version)" {Get-Pinned $pins.comfyui (Join-Path $dl 'comfyui.zip');Unzip-Flat (Join-Path $dl 'comfyui.zip') $comfy 'main.py'}
Step 'python' "สร้าง Python $($t.python) ของ ComfyUI" {if(-not (Test-Path -LiteralPath $py)){Exe $uv @('venv','--python',$t.python,'--seed',(Join-Path $comfy '.venv'))}}
$constraints=Join-Path $Root 'torch-pins.txt'
[IO.File]::WriteAllText($constraints,("torch=={0}`ntorchvision=={1}`ntorchaudio=={2}`n" -f $t.torch,$t.torchvision,$t.torchaudio))
Step 'torch' "ติดตั้ง PyTorch $($t.torch) (ไฟล์ใหญ่หลาย GB ใช้เวลาสักพัก)" {
 $extra=if($target){"[device-$target]"}else{''}
 Exe $uv @('pip','install','--python',$py,'--index-url',$t.index,"torch$extra==$($t.torch)","torchvision$extra==$($t.torchvision)","torchaudio==$($t.torchaudio)")
}
Step 'requirements' 'ติดตั้งแพ็กเกจของ ComfyUI + ComfyUI-Manager' {
 $req=@('-r',(Join-Path $comfy 'requirements.txt'))
 if(Test-Path -LiteralPath (Join-Path $comfy 'manager_requirements.txt')){$req+=@('-r',(Join-Path $comfy 'manager_requirements.txt'))}
 Exe $uv (@('pip','install','--python',$py,'-c',$constraints)+$req)
}

# 4) GPU check: PyTorch must see the chosen card and run on it.
Say "`n== ทดสอบการ์ดจอกับ PyTorch" Cyan
$names=& $py -c "import torch,json;print(json.dumps([torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())]))"
if($LASTEXITCODE -ne 0 -or -not $names){Fail 'PyTorch โหลดไม่ขึ้น ดูข้อความด้านบน'}
$list=@($names | Select-Object -Last 1 | ConvertFrom-Json)
if(-not $list.Count){Fail $(if($kind -eq 'rocm'){'PyTorch มองไม่เห็นการ์ด AMD: อัปเดตไดรเวอร์ AMD Adrenalin เป็นรุ่นล่าสุดแล้วรันตัวติดตั้งซ้ำ'}else{'PyTorch มองไม่เห็นการ์ด NVIDIA: อัปเดตไดรเวอร์แล้วรันซ้ำ'})}
function Clean($s){($s.ToLower() -replace '[^a-z0-9]','') -replace 'advancedmicrodevices|nvidia|amd|graphics|geforce',''}
$hit=@();for($i=0;$i -lt $list.Count;$i++){if((Clean $list[$i]) -eq (Clean $gpu.name)){$hit+=$i}}
$dev=if($hit.Count -eq 1){$hit[0]}elseif($list.Count -eq 1){0}else{Fail ('มีการ์ดหลายใบและจับคู่ไม่ได้: ' + ($list -join ', '))}
$visible=if($kind -eq 'rocm'){'HIP_VISIBLE_DEVICES'}else{'CUDA_VISIBLE_DEVICES'}
Set-Item -Path "env:$visible" -Value ([string]$dev)
Exe $py @('-c','import torch;assert torch.cuda.is_available();x=torch.randn(512,512,device=''cuda'');print(''GPU OK:'',torch.cuda.get_device_name(0),float((x@x).sum().cpu())!=0)')

# 5) Launchers
$flags='--enable-manager --auto-launch'+$(if($low){' --lowvram'}else{''})
$run="@echo off`r`ntitle ComfyUI`r`ncd /d ""%~dp0ComfyUI""`r`nset $visible=$dev`r`n"".venv\Scripts\python.exe"" main.py $flags %*`r`npause`r`n"
[IO.File]::WriteAllText((Join-Path $Root 'Run ComfyUI.cmd'),$run,(New-Object Text.ASCIIEncoding))
$lan="@echo off`r`ntitle ComfyUI (LAN)`r`ncd /d ""%~dp0ComfyUI""`r`nset $visible=$dev`r`n"".venv\Scripts\python.exe"" main.py $flags --listen 0.0.0.0 %*`r`npause`r`n"
[IO.File]::WriteAllText((Join-Path $Root 'Run ComfyUI (LAN).cmd'),$lan,(New-Object Text.ASCIIEncoding))
Save-State @{device=$dev;finishedAt=[DateTime]::Now.ToString('s')}

Say "`nติดตั้งเสร็จแล้ว" Green
Say "เปิดใช้งาน: ดับเบิลคลิก $Root\Run ComfyUI.cmd (เบราว์เซอร์จะเปิด http://127.0.0.1:8188 เอง)"
Say "ใส่โมเดล: $comfy\models\  (checkpoints, diffusion_models, text_encoders, vae, loras ...)"
Say "ถอนการติดตั้ง: ลบโฟลเดอร์ $Root ทิ้งทั้งโฟลเดอร์ ไม่มีอะไรติดตั้งลงระบบ"
