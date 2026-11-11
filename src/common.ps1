# Shared by install.ps1 and update.ps1 (dot-sourced). Each script sets a top-level trap that prints Fail messages.
function Say($text,$color='Gray'){Write-Host $text -ForegroundColor $color}
function Fail($text){throw [Exception]::new($text)}
$script:RetryHint=''
function Exe($file,[string[]]$arguments){& $file @arguments | Out-Host;if($LASTEXITCODE -ne 0){Fail ("คำสั่งล้มเหลว ({0}): {1} {2}{3}" -f $LASTEXITCODE,(Split-Path $file -Leaf),($arguments -join ' '),$script:RetryHint)}}
function Save-Json($path,$obj){[IO.File]::WriteAllText($path,($obj|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding $false))}

# Everything uv touches stays inside the install folder: delete the folder = uninstall.
function Use-RootEnv($Root){
 $env:UV_PYTHON_INSTALL_DIR=Join-Path $Root 'runtime\python'
 $env:UV_CACHE_DIR=Join-Path $Root '.uv-cache'
 $env:UV_LINK_MODE='copy'
 $env:UV_HTTP_TIMEOUT='600'
}

# ComfyUI is pinned by commit. pygit2 fetches it, so Git does not have to be installed,
# and fetch_comfyui.py refuses to install if the tag does not point at the pinned commit.
function Get-ComfyUISource($uv,$python,$dest){
 $tmp="$dest.fetch";if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Recurse -Force}
 Exe $uv @('run','--no-project','--isolated','--python',$python,'--with',"pygit2==$($pins.pygit2)",'python',(Join-Path $kit 'src\fetch_comfyui.py'),$pins.comfyui.repo,$pins.comfyui.version,$pins.comfyui.commit,$tmp)
 if(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Recurse -Force}
 Move-Item -LiteralPath $tmp -Destination $dest
}

function Write-TorchPins($file,$t){[IO.File]::WriteAllText($file,("torch=={0}`ntorchvision=={1}`ntorchaudio=={2}`n" -f $t.torch,$t.torchvision,$t.torchaudio))}
function Install-Torch($uv,$py,$t,$target){
 $extra=if($target){"[device-$target]"}else{''}
 Exe $uv @('pip','install','--python',$py,'--index-url',$t.index,"torch$extra==$($t.torch)","torchvision$extra==$($t.torchvision)","torchaudio==$($t.torchaudio)")
}
function Install-Requirements($uv,$py,$comfy,$constraints){
 $req=@('-r',(Join-Path $comfy 'requirements.txt'))
 if(Test-Path -LiteralPath (Join-Path $comfy 'manager_requirements.txt')){$req+=@('-r',(Join-Path $comfy 'manager_requirements.txt'))}
 Exe $uv (@('pip','install','--python',$py,'-c',$constraints)+$req)
}
# ComfyUI-Manager imports GitPython, which crashes when Git is not installed (most Windows PCs),
# so the Manager never loads. With pygit2 present and CM_USE_PYGIT2=1 the Manager uses pygit2 instead.
function Install-ManagerGit($uv,$py,$constraints){Exe $uv @('pip','install','--python',$py,'-c',$constraints,"pygit2==$($pins.pygit2)")}

# PyTorch must see the chosen card and run on it. Returns the device index to pin in the launchers.
function Test-Gpu($py,$kind,$gpuName){
 $names=& $py -c "import torch,json;print(json.dumps([torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())]))"
 if($LASTEXITCODE -ne 0 -or -not $names){Fail 'PyTorch โหลดไม่ขึ้น ดูข้อความด้านบน'}
 $list=@($names | Select-Object -Last 1 | ConvertFrom-Json)
 if(-not $list.Count){Fail $(if($kind -eq 'rocm'){'PyTorch มองไม่เห็นการ์ด AMD: อัปเดตไดรเวอร์ AMD Adrenalin เป็นรุ่นล่าสุดแล้วลองใหม่'}else{'PyTorch มองไม่เห็นการ์ด NVIDIA: อัปเดตไดรเวอร์แล้วลองใหม่'})}
 function Clean($s){($s.ToLower() -replace '[^a-z0-9]','') -replace 'advancedmicrodevices|nvidia|amd|graphics|geforce',''}
 $hit=@();for($i=0;$i -lt $list.Count;$i++){if((Clean $list[$i]) -eq (Clean $gpuName)){$hit+=$i}}
 $dev=if($hit.Count -eq 1){$hit[0]}elseif($list.Count -eq 1){0}else{Fail ('มีการ์ดหลายใบและจับคู่ไม่ได้: ' + ($list -join ', '))}
 $visible=Get-VisibleVar $kind
 $prev=[Environment]::GetEnvironmentVariable($visible)
 Set-Item -Path "env:$visible" -Value ([string]$dev)
 try{Exe $py @('-c','import torch;assert torch.cuda.is_available();x=torch.randn(512,512,device=''cuda'');print(''GPU OK:'',torch.cuda.get_device_name(0),float((x@x).sum().cpu())!=0)')}
 finally{[Environment]::SetEnvironmentVariable($visible,$prev)}
 return $dev
}
function Get-VisibleVar($kind){if($kind -eq 'rocm'){'HIP_VISIBLE_DEVICES'}else{'CUDA_VISIBLE_DEVICES'}}

# python.exe processes started from this install folder (ComfyUI running, or a Manager install in progress).
function Get-RunningFrom($Root){
 $p=$Root.TrimEnd('\')+'\'
 @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue | Where-Object {
  ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($p,[StringComparison]::OrdinalIgnoreCase)) -or ($_.CommandLine -and $_.CommandLine.IndexOf($p,[StringComparison]::OrdinalIgnoreCase) -ge 0)})
}
