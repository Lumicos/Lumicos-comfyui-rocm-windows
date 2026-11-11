param([string]$Root,[switch]$Yes,[switch]$Force,[switch]$Restore,[string]$Backup)
# Update an existing install to the ComfyUI version in pins.json, keeping the old one as a backup,
# or (-Restore) switch back to a backup. Models, input, output and user (settings, workflows) move
# with whichever version is active; the backup keeps its own code, Python env and custom_nodes.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$kit=$PSScriptRoot
$pins=Get-Content -LiteralPath (Join-Path $kit 'pins.json') -Raw | ConvertFrom-Json
. (Join-Path $kit 'src\common.ps1')
trap{Say "`n[หยุด] $($_.Exception.Message)" Red;exit 1}
$Shared=@('models','input','output','user')

Say $(if($Restore){'ComfyUI - กู้คืนจากตัวสำรอง'}else{"ComfyUI - อัปเดตเป็น $($pins.comfyui.version) (สำรองตัวเก่าไว้ให้)"}) Cyan

# 1) Which install
if(-not $Root){$default='C:\ComfyUI';if($Yes){$Root=$default}else{$a=Read-Host "โฟลเดอร์ที่ติดตั้ง ComfyUI ไว้ [เว้นว่าง = $default]";$Root=if($a){$a}else{$default}}}
$Root=[IO.Path]::GetFullPath($Root.Trim().Trim('"'))
$marker=Join-Path $Root 'installer-state.json'
if(-not (Test-Path -LiteralPath $marker)){Fail "ไม่พบการติดตั้งที่ $Root (ไม่มี installer-state.json) ถ้ายังไม่เคยติดตั้งให้ใช้ Install ComfyUI.cmd"}
$state=Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
if(-not $state.finishedAt){Fail 'การติดตั้งครั้งก่อนยังไม่เสร็จ ให้รัน Install ComfyUI.cmd กับโฟลเดอร์นี้ให้จบก่อน'}
$comfy=Join-Path $Root 'ComfyUI'
$backups=Join-Path $Root 'backups'
$stamp=[DateTime]::Now.ToString('yyyyMMdd-HHmmss')
$cur=if($state.comfyui){$state.comfyui}else{'unknown'}
Say "ติดตั้งอยู่ตอนนี้: ComfyUI $cur, PyTorch $($state.torch) ($($state.gpu))"

Use-RootEnv $Root
$uv=Join-Path $Root 'runtime\uv\uv.exe'
if(-not (Test-Path -LiteralPath $uv)){Fail "ไม่พบ $uv ให้รัน Install ComfyUI.cmd กับโฟลเดอร์นี้ก่อน"}
$curPy=Join-Path $comfy '.venv\Scripts\python.exe'
$pinsFile=Join-Path $Root 'torch-pins.txt'
$running=Get-RunningFrom $Root
if($running.Count){Fail ('ComfyUI ยังเปิดอยู่ (python.exe PID ' + (($running|ForEach-Object ProcessId) -join ', ') + ') ปิดหน้าต่าง ComfyUI ก่อนแล้วลองใหม่')}

function Move-Shared($from,$to){
 # Move user data from one ComfyUI folder to another. Folders the target ships empty (e.g. models\checkpoints) are merged in.
 foreach($n in $Shared){
  $src=Join-Path $from $n;if(-not (Test-Path -LiteralPath $src)){continue}
  $dst=Join-Path $to $n
  $skel=$null
  if(Test-Path -LiteralPath $dst){$skel="$dst.skel-$stamp";Move-Item -LiteralPath $dst -Destination $skel}
  Move-Item -LiteralPath $src -Destination $dst
  if($skel){
   Get-ChildItem -LiteralPath $skel -Force | ForEach-Object {if(-not (Test-Path -LiteralPath (Join-Path $dst $_.Name))){Move-Item -LiteralPath $_.FullName -Destination $dst}}
   Remove-Item -LiteralPath $skel -Recurse -Force
  }
 }
}
# Make `active` the running ComfyUI and park the current one in backups\ as $parkName.
function Switch-Active($active,$parkName,$parkInfo){
 $park=Join-Path $backups $parkName
 New-Item -ItemType Directory -Force -Path $backups | Out-Null
 Move-Shared $comfy $active
 try{Move-Item -LiteralPath $comfy -Destination $park}
 catch{Move-Shared $active $comfy;Fail "ย้ายโฟลเดอร์ $comfy ไม่ได้ (มีโปรแกรมเปิดไฟล์ในนั้นค้างอยู่ เช่น Explorer หรือ terminal) ปิดแล้วลองใหม่: $($_.Exception.Message)"}
 Move-Item -LiteralPath $active -Destination $comfy
 Save-Json (Join-Path $park 'backup-info.json') $parkInfo
 return $park
}
function Fix-Launchers{
 foreach($f in 'Run ComfyUI.cmd','Run ComfyUI (LAN).cmd'){
  $p=Join-Path $Root $f;if(-not (Test-Path -LiteralPath $p)){continue}
  $txt=[IO.File]::ReadAllText($p)
  if($txt -notmatch 'CM_USE_PYGIT2'){$txt=$txt -replace '(?m)^(set (HIP|CUDA)_VISIBLE_DEVICES=.*)\r?$',"`$1`r`nset CM_USE_PYGIT2=1`r";[IO.File]::WriteAllText($p,$txt,(New-Object Text.ASCIIEncoding))}
 }
}
function New-ParkInfo($reason){[ordered]@{comfyui=$cur;torch=$state.torch;createdAt=[DateTime]::Now.ToString('s');reason=$reason;torchPins=$(if(Test-Path -LiteralPath $pinsFile){[IO.File]::ReadAllText($pinsFile)}else{$null})}}
function Save-State($o){$s=[ordered]@{};foreach($p in $state.PSObject.Properties){$s[$p.Name]=$p.Value};foreach($k in $o.Keys){$s[$k]=$o[$k]};Save-Json $marker $s}

# ---- Restore ----
if($Restore){
 $list=@(Get-ChildItem -LiteralPath $backups -Directory -ErrorAction SilentlyContinue | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'main.py')} | Sort-Object Name -Descending)
 if(-not $list.Count){Fail "ไม่มีตัวสำรองใน $backups"}
 $info=@{};foreach($b in $list){$f=Join-Path $b.FullName 'backup-info.json';$info[$b.Name]=if(Test-Path -LiteralPath $f){Get-Content -LiteralPath $f -Raw | ConvertFrom-Json}else{$null}}
 if($Backup){$pick=$list | Where-Object Name -eq $Backup | Select-Object -First 1;if(-not $pick){Fail "ไม่พบตัวสำรองชื่อ $Backup"}}
 else{
  for($i=0;$i -lt $list.Count;$i++){$x=$info[$list[$i].Name];Say ("  {0}) {1}   ComfyUI {2}, PyTorch {3}" -f ($i+1),$list[$i].Name,$x.comfyui,$x.torch)}
  $n=1;if(-not $Yes){$a=Read-Host 'เลือกตัวสำรองที่จะกู้คืน [เว้นว่าง = 1]';if($a){$n=[int]$a}}
  if($n -lt 1 -or $n -gt $list.Count){Fail 'เลขไม่ถูกต้อง'}
  $pick=$list[$n-1]
 }
 $x=$info[$pick.Name]
 if(-not $Yes){$a=Read-Host "กู้คืน $($pick.Name) แทน ComfyUI $cur ? ตัวปัจจุบันจะถูกย้ายไปเก็บใน backups (Y/N)";if($a -notmatch '^[yY]'){exit 0}}
 $park=Switch-Active $pick.FullName "ComfyUI-$cur-$stamp" (New-ParkInfo 'restore')
 Remove-Item -LiteralPath (Join-Path $comfy 'backup-info.json') -Force -ErrorAction SilentlyContinue
 if($x -and $x.torchPins){[IO.File]::WriteAllText($pinsFile,$x.torchPins)}
 Fix-Launchers
 # Backups made before this fix have no pygit2, and the Manager needs it when Git is not installed.
 & $uv pip install --python $curPy -c $pinsFile "pygit2==$($pins.pygit2)" | Out-Host
 if($LASTEXITCODE -ne 0){Say '[เตือน] ติดตั้ง pygit2 ไม่ผ่าน ถ้าหน้า Manager ไม่ขึ้นให้รัน Install ComfyUI.cmd กับโฟลเดอร์นี้' Yellow}
 Save-State ([ordered]@{comfyui=$(if($x){$x.comfyui}else{'unknown'});torch=$(if($x){$x.torch}else{$state.torch});updatedAt=[DateTime]::Now.ToString('s')})
 Say "`nกู้คืนเสร็จแล้ว: ใช้ ComfyUI $(if($x){$x.comfyui}) จาก $($pick.Name)" Green
 Say "ตัวที่เพิ่งถอดออกเก็บไว้ที่ $park"
 exit 0
}

# ---- Update ----
if(-not $state.kind -or -not $pins.torch.($state.kind)){Fail 'ข้อมูลการติดตั้งไม่ครบ (installer-state.json) ใช้ Install ComfyUI.cmd ติดตั้งใหม่ในโฟลเดอร์ใหม่'}
$t=$pins.torch.($state.kind)
if($cur -eq $pins.comfyui.version -and -not $Force){
 Install-ManagerGit $uv $curPy $pinsFile
 Fix-Launchers
 Say "`nเป็นรุ่นล่าสุดของตัวติดตั้งนี้แล้ว ($cur) ไม่ต้องอัปเดต" Green
 Say 'ถ้าต้องการรุ่นใหม่กว่านี้ ให้ดาวน์โหลดตัวติดตั้ง (Code -> Download ZIP) ชุดใหม่ แล้วรัน Update ComfyUI.cmd จากชุดใหม่'
 exit 0
}
Say ("แผน: ComfyUI {0} -> {1}, PyTorch {2}" -f $cur,$pins.comfyui.version,$t.torch) Green
Say "ตัวเก่าจะถูกเก็บไว้ที่ $backups\ComfyUI-$cur-$stamp (โค้ด + Python + custom_nodes) ส่วน models / input / output / user ย้ายตามมาใช้กับตัวใหม่"
$drive=Get-PSDrive -Name $Root.Substring(0,1) -ErrorAction SilentlyContinue
if($drive -and $drive.Free -lt 15GB){Say ("พื้นที่ว่างไดรฟ์ {0}: เหลือ {1:N1} GB ตัวใหม่ต้องใช้ประมาณ 10 GB เพราะตัวเก่ายังเก็บไว้" -f $drive.Name,($drive.Free/1GB)) Yellow}
if(-not $Yes){$a=Read-Host 'เริ่มอัปเดต? (Y/N)';if($a -notmatch '^[yY]'){exit 0}}

$new=Join-Path $Root 'ComfyUI.new'
$py=Join-Path $new '.venv\Scripts\python.exe'
$constraints=Join-Path $Root 'torch-pins.new.txt'
# Nothing in the running install is touched until the new one has passed the GPU test.
try{
 Say "`n== ดาวน์โหลด ComfyUI $($pins.comfyui.version)" Cyan
 Get-ComfyUISource $uv $t.python $new
 Say "`n== สร้าง Python $($t.python) ชุดใหม่" Cyan
 Exe $uv @('venv','--python',$t.python,'--seed','--relocatable',(Join-Path $new '.venv'))
 Write-TorchPins $constraints $t
 Say "`n== ติดตั้ง PyTorch $($t.torch) (ถ้ารุ่นเดิม จะใช้ไฟล์ที่ดาวน์โหลดไว้แล้ว)" Cyan
 Install-Torch $uv $py $t $state.target
 Say "`n== ติดตั้งแพ็กเกจของ ComfyUI + ComfyUI-Manager" Cyan
 Install-Requirements $uv $py $new $constraints
 Install-ManagerGit $uv $py $constraints
 Say "`n== คัดลอก custom_nodes และติดตั้งแพ็กเกจที่มันต้องใช้" Cyan
 $nodes=Join-Path $comfy 'custom_nodes'
 if(Test-Path -LiteralPath $nodes){
  Get-ChildItem -LiteralPath $nodes -Force | Where-Object Name -ne '__pycache__' | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $new 'custom_nodes') -Recurse -Force}
  foreach($d in Get-ChildItem -LiteralPath (Join-Path $new 'custom_nodes') -Directory){
   $r=Join-Path $d.FullName 'requirements.txt'
   if($d.Name -match '\.disabled$' -or -not (Test-Path -LiteralPath $r)){continue}
   Say "  $($d.Name)"
   & $uv pip install --python $py -c $constraints -r $r | Out-Host
   if($LASTEXITCODE -ne 0){Say "  [เตือน] ติดตั้งแพ็กเกจของ $($d.Name) ไม่ผ่าน node นี้อาจใช้ไม่ได้ ลองกด Fix ใน Manager ภายหลัง" Yellow}
  }
 }
 foreach($f in 'extra_model_paths.yaml'){$p=Join-Path $comfy $f;if(Test-Path -LiteralPath $p){Copy-Item -LiteralPath $p -Destination $new -Force}}
 Say "`n== ทดสอบการ์ดจอกับ PyTorch ชุดใหม่" Cyan
 $dev=Test-Gpu $py $state.kind $state.gpu
 if($state.device -ne $null -and [int]$dev -ne [int]$state.device){Say "[เตือน] ลำดับการ์ดเปลี่ยนจาก $($state.device) เป็น $dev ให้รัน Install ComfyUI.cmd ซ้ำเพื่อสร้างไฟล์ Run ใหม่" Yellow}
}catch{
 Say "`nอัปเดตไม่สำเร็จ ลบของที่ดาวน์โหลดมาครึ่งทาง ตัวเดิมยังใช้ได้ตามปกติ ไม่ได้ถูกแตะ" Yellow
 foreach($p in $new,"$new.fetch"){if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue}}
 Remove-Item -LiteralPath $constraints -Force -ErrorAction SilentlyContinue
 throw
}

Say "`n== สลับไปใช้ตัวใหม่" Cyan
$park=Switch-Active $new "ComfyUI-$cur-$stamp" (New-ParkInfo 'update')
Move-Item -LiteralPath $constraints -Destination $pinsFile -Force
Fix-Launchers
Save-State ([ordered]@{comfyui=$pins.comfyui.version;torch=$t.torch;updatedAt=[DateTime]::Now.ToString('s')})

Say "`nอัปเดตเสร็จแล้ว: ComfyUI $($pins.comfyui.version)" Green
Say "เปิดใช้งานเหมือนเดิม: $Root\Run ComfyUI.cmd"
Say "ตัวเก่าเก็บไว้ที่: $park"
Say "ถ้าตัวใหม่มีปัญหา ดับเบิลคลิก Restore ComfyUI.cmd เพื่อกลับไปใช้ตัวเก่า"
Say 'ตัวสำรองแต่ละชุดกินพื้นที่หลาย GB ใช้ตัวใหม่จนมั่นใจแล้วลบโฟลเดอร์ใน backups ทิ้งได้เลย'
