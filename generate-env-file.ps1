Param(
  [string]$source,
  [string]$target,
  [switch]$sample
)
if ([string]::IsNullOrEmpty($source))
{
  $source = -Join((Get-Location).Path, '\source')
}
$sourcePath = (Resolve-Path $source).Path
if ([string]::IsNullOrEmpty($sourcePath))
{
  echo "source is not exists: $source"
  exit
}
if ([string]::IsNullOrEmpty($target))
{
  $target = -Join((Get-Location).Path, '\transfer-file-to-docker-by-env-file.env')
}
$extract=@'
k=1
while true; do
  eval c=\$_T_${k}_C
  if [ -z $c ]; then
    exit;
  fi
  eval n=\$_T_${k}_N
  echo $c | base64 -d > /dev/shm/$n;
  k=`expr $k + 1`
done;
'@
Write-Host 'extract script:'
Write-Host ''
Write-Host $extract
Write-Host ''
Write-Output _T_0_C=$([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($extract.Replace("`r`n", "`n")))) |
Out-File $target -Encoding UTF8

$k=1
Get-ChildItem $sourcePath -File |
ForEach-Object -Process{
  Write-Host ''
  Write-Host 'File Number : ' $k
  Write-Host 'File Name : ' $_.Name
  Write-Output _T_${k}_N=$_
  Write-Output _T_${k}_C=$([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($_.FullName)))
  $k=$k+1
} |
Out-File $target -Append -Encoding UTF8
if($sample.isPresent)
{
  $sampleCompose=@"
  version: `"3`"
  services:
    sample:
      image: alpine
      env_file:
        - $(([system.io.fileinfo]$target).Name)
      entrypoint: |
        /bin/sh
        -c
        `"export;
        echo `$`$_T_0_C | base64 -d | /bin/sh;
        ls -al /dev/shm`"
"@
  Write-Host ''
  $sampleYmlFile = -Join(([system.io.fileinfo]$target).DirectoryName, '\', ([system.io.fileinfo]$target).BaseName, '.yml')
  Write-Output $sampleCompose | Out-File $sampleYmlFile -Encoding UTF8
  Write-Host 'Sample Docker Compose File :' $sampleYmlFile
  Write-Host ''
  Write-Host "Usage : docker-compose -f $sampleYmlFile up"
}
