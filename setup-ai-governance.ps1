<#
.SYNOPSIS
    setup-ai-governance.ps1 v2.3.1
    Despliega el marco de Gobernanza de IA e Ingeniería de Software
    (25 Pilares + Commit y PR Workflows) para OpenCode, Google Antigravity
    y Claude Code.

.DESCRIPTION
    Port fiel de setup-ai-governance.sh v2.3.1 a PowerShell.
    El contenido literal reside en content/ (fuente única); este script es un
    adaptador delgado que carga plantillas, valida entradas, aplica un gate
    humano, escribe de forma atómica y registra un log JSONL con hash SHA-256.

.PARAMETER DryRun
    Muestra lo que haría sin modificar nada.

.PARAMETER Force
    Sobrescribe archivos que ya existan sin marker de este script.

.PARAMETER NoBackup
    No crear backups .bak.TIMESTAMP al sobrescribir.

.PARAMETER Uninstall
    Elimina los archivos creados por este script (lee el state file).

.PARAMETER Targets
    Lista CSV: opencode,gemini,claude | all (default: opencode,gemini,claude)

.PARAMETER Yes
    Acepta el gate humano. Solo para CI controlado por una persona responsable.

.PARAMETER AllowMissingMcp
    Permite desplegar aunque no se encuentre el binario codebase-memory-mcp.

.NOTES
    Version : 2.3.1

    Cambios 2.3.1:
      * Detecta el binario en $env:USERPROFILE\AppData\Local\Programs\
        (ruta real del instalador de Windows) sin hardcodear el usuario

    Cambios 2.3.0:
      * Fuente única de contenido en content/ (elimina duplicación y drift)
      * Log JSONL con correlation_id y cadena SHA-256 (prev_hash)
      * Gate humano obligatorio antes de escribir (-Yes para CI)
      * Validación estricta de variables de entorno inyectadas en prompts
      * Fail-fast del binario MCP (-AllowMissingMcp para omitir)
      * Rollback compensatorio multi-target y kill switch por centinela
      * Enmascaramiento del home en logs y ACL restrictiva best-effort

    Cambios 2.2.3:
      * Fix: validación final de JSON con parser case-sensitive
        (ConvertFrom-Json rechazaba claves válidas que solo difieren en mayúsculas,
        p. ej. *secret* / *Secret* en permission.read de opencode.json).

    License : MIT

    Variables de entorno opcionales:
      AI_AGENT_NAME_OPENCODE/GEMINI/CLAUDE, AI_AGENT_DISPLAY_OPENCODE/GEMINI/CLAUDE
      AI_MCP_VERSION, AI_MCP_SHA256 (AI-BOM del servidor MCP)
#>
[CmdletBinding()]
param(
    [Alias('n')][switch]$DryRun,
    [Alias('f')][switch]$Force,
    [switch]$NoBackup,
    [switch]$Uninstall,
    [string]$Targets = 'opencode,gemini,claude',
    [Alias('y')][switch]$Yes,
    [switch]$AllowMissingMcp,
    [Alias('h')][switch]$Help,
    [switch]$Version
)

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptVersion = '2.3.1'
$script:ScriptName    = [System.IO.Path]::GetFileName($PSCommandPath)
$script:ScriptDir     = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:ContentDir    = Join-Path $script:ScriptDir 'content'

# ==============================================================================
# USAGE
# ==============================================================================
function Show-Usage {
    Write-Host @"
$($script:ScriptName) v$($script:ScriptVersion)

Despliega el marco de Gobernanza de IA (25 pilares + workflows) para
OpenCode, Google Antigravity (Gemini) y Claude Code.

USO:
    $($script:ScriptName) [-DryRun] [-Force] [-NoBackup] [-Uninstall]
                          [-Targets <LIST>] [-Yes] [-AllowMissingMcp]
                          [-Help] [-Version]

OPCIONES:
    -DryRun  (-n)     Muestra lo que haría sin modificar nada
    -Force   (-f)     Sobrescribe archivos sin marker de este script
    -NoBackup         No crea backups .bak.TIMESTAMP
    -Uninstall        Elimina los archivos creados por este script
    -Targets <LIST>   CSV: opencode,gemini,claude | all
    -Yes     (-y)     Acepta el gate humano (solo CI controlado)
    -AllowMissingMcp  Despliega aunque falte el binario MCP
    -Help    (-h)     Muestra esta ayuda
    -Version          Imprime la versión
"@
}

if ($Help)    { Show-Usage; exit 0 }
if ($Version) { Write-Output $script:ScriptVersion; exit 0 }

# ==============================================================================
# VALIDATE TARGETS
# ==============================================================================
if ($Targets -eq 'all') { $Targets = 'opencode,gemini,claude' }
$script:TargetList = @($Targets -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($t in $script:TargetList) {
    if ($t -notin @('opencode','gemini','claude')) {
        Write-Error "Target inválido: '$t' (permitidos: opencode, gemini, claude, all)"
        exit 2
    }
}
if ($script:TargetList.Count -eq 0) {
    Write-Error "Targets vacío (permitidos: opencode, gemini, claude, all)"
    exit 2
}
function Test-TargetEnabled {
    param([string]$Name)
    return ($script:TargetList -contains $Name)
}

# ==============================================================================
# PATHS
# ==============================================================================
$script:UserHome       = if ($HOME) { $HOME } else { $env:USERPROFILE }
$script:OpenCodeRoot   = Join-Path (Join-Path $script:UserHome '.config') 'opencode'
$script:OpenCodeDocs   = Join-Path $script:OpenCodeRoot 'docs'
$script:OpenCodeCmds   = Join-Path $script:OpenCodeRoot 'commands'
$script:GeminiRoot     = Join-Path $script:UserHome '.gemini'
$script:GeminiDocs     = Join-Path $script:GeminiRoot 'docs'
$script:AntiRoot       = Join-Path $script:GeminiRoot 'antigravity'
$script:AntiWorkflows  = Join-Path $script:AntiRoot 'global_workflows'
$script:ClaudeRoot     = Join-Path $script:UserHome '.claude'
$script:ClaudeDocs     = Join-Path $script:ClaudeRoot 'docs'
$script:GovOpenCode    = Join-Path $script:OpenCodeDocs 'AI_GOVERNANCE.md'
$script:GovGemini      = Join-Path $script:GeminiDocs   'AI_GOVERNANCE.md'
$script:GovClaude      = Join-Path $script:ClaudeDocs   'AI_GOVERNANCE.md'
$script:StateDir       = Join-Path (Join-Path $script:UserHome '.config') 'ai-governance'
$script:StateFile      = Join-Path $script:StateDir 'installed.txt'
$script:AbortFile      = Join-Path $script:StateDir 'ABORT'
$script:LogDir         = Join-Path (Join-Path $script:UserHome '.local') 'state'

# ==============================================================================
# LOGGING ESTRUCTURADO JSONL + SHA-256 (Pilares 6 y 20)
# ==============================================================================
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null
}
$script:LogFile = Join-Path $script:LogDir ("ai-governance-setup.{0}.{1}.jsonl" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID)
$script:CorrelationId = ("{0}-{1}-{2}" -f (Get-Date -Format 'yyyyMMddHHmmss'), $PID, [guid]::NewGuid().ToString('N').Substring(0,12))
$script:LogSeq = 0
$script:PrevHash = '0' * 64
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Set-PrivatePath {
    param([string]$Path)
    try {
        if ($env:OS -eq 'Windows_NT') {
            & icacls $Path /inheritance:r /grant:r "$($env:USERNAME):(F)" 2>$null | Out-Null
        } elseif (Get-Command chmod -ErrorAction SilentlyContinue) {
            & chmod 700 $Path 2>$null | Out-Null
        }
    } catch { }
}

function Write-AuditEvent {
    param([string]$Level, [string]$Message)
    $script:LogSeq++
    # Pilar 24: enmascarar la ruta personal.
    $message = $Message.Replace($script:UserHome, '<HOME>')
    $payload = [ordered]@{
        ts             = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        level          = $Level
        message        = $message
        correlation_id = $script:CorrelationId
        seq            = $script:LogSeq
        prev_hash      = $script:PrevHash
    }
    $payloadJson = $payload | ConvertTo-Json -Compress
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = ([System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payloadJson)))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
    $line = $payloadJson.TrimEnd('}') + ',"hash":"' + $hash + '"}'
    Write-Host $line
    if (-not $DryRun) {
        [System.IO.File]::AppendAllText($script:LogFile, "$line`n", $script:Utf8NoBom)
        if ($script:LogSeq -eq 1) { Set-PrivatePath -Path $script:LogFile }
    }
    $script:PrevHash = $hash
}

function Log-Info  { param([string]$m) Write-AuditEvent 'INFO' $m }
function Log-Warn  { param([string]$m) Write-AuditEvent 'WARN' $m }
function Log-Error { param([string]$m) Write-AuditEvent 'ERROR' $m }
function Log-Dry   { param([string]$m) Write-AuditEvent 'DRY' $m }

# Pilar 5: la divulgación debe ser el primer evento de la cadena, antes de
# cualquier advertencia emitida durante la resolución de dependencias.
Write-AuditEvent 'AI_DISCLOSURE' 'Asistido por IA (OpenCode); supervisión humana requerida'

# ==============================================================================
# CONTENIDO (fuente única) Y VALIDACIÓN DE IDENTIDAD (Pilares 11, 15, 21)
# ==============================================================================
$script:ContentFiles = @('AI_GOVERNANCE.md','AGENTS.md.tmpl','audit-governance.md','commit.md.tmpl','pr.md.tmpl')
foreach ($f in $script:ContentFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $script:ContentDir $f) -PathType Leaf)) {
        Write-Error "Falta el archivo de contenido $(Join-Path $script:ContentDir $f)"
        exit 1
    }
}
$script:AgentsTemplate = [System.IO.File]::ReadAllText((Join-Path $script:ContentDir 'AGENTS.md.tmpl'), $script:Utf8NoBom)
$script:AuditPrompt    = [System.IO.File]::ReadAllText((Join-Path $script:ContentDir 'audit-governance.md'), $script:Utf8NoBom)
$script:CommitTemplate = [System.IO.File]::ReadAllText((Join-Path $script:ContentDir 'commit.md.tmpl'), $script:Utf8NoBom)
$script:PrTemplate     = [System.IO.File]::ReadAllText((Join-Path $script:ContentDir 'pr.md.tmpl'), $script:Utf8NoBom)

function Get-EnvOrDefault {
    param([string]$Name, [string]$Default)
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return $v
}
function Assert-ValidIdentity {
    param([string]$Value, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 120 -or $Value -notmatch '^[A-Za-z0-9 <>.@_-]+$') {
        Log-Error "Identidad inválida en ${Name}: vacía, >120 caracteres o caracteres no permitidos"
        exit 2
    }
}

$script:AgentNameOpenCode = Get-EnvOrDefault 'AI_AGENT_NAME_OPENCODE' 'OpenCode <noreply@opencode.ai>'
$script:AgentNameGemini   = Get-EnvOrDefault 'AI_AGENT_NAME_GEMINI'   'Gemini <noreply@google.com>'
$script:AgentNameClaude   = Get-EnvOrDefault 'AI_AGENT_NAME_CLAUDE'   'Claude Code <noreply@anthropic.com>'
$script:AgentDispOpenCode = Get-EnvOrDefault 'AI_AGENT_DISPLAY_OPENCODE' 'OpenCode'
$script:AgentDispGemini   = Get-EnvOrDefault 'AI_AGENT_DISPLAY_GEMINI'   'Gemini'
$script:AgentDispClaude   = Get-EnvOrDefault 'AI_AGENT_DISPLAY_CLAUDE'   'Claude Code'

foreach ($pair in @(
    @('AI_AGENT_NAME_OPENCODE', $script:AgentNameOpenCode),
    @('AI_AGENT_NAME_GEMINI',   $script:AgentNameGemini),
    @('AI_AGENT_NAME_CLAUDE',   $script:AgentNameClaude),
    @('AI_AGENT_DISPLAY_OPENCODE', $script:AgentDispOpenCode),
    @('AI_AGENT_DISPLAY_GEMINI',   $script:AgentDispGemini),
    @('AI_AGENT_DISPLAY_CLAUDE',   $script:AgentDispClaude)
)) {
    Assert-ValidIdentity -Value $pair[1] -Name $pair[0]
}

function Apply-AgentSubs {
    param([string]$Content, [string]$Name, [string]$Display, [string]$GovPath)
    $Content = $Content.Replace('__GOV_PATH__', $GovPath)
    $Content = $Content.Replace('AI_AGENT_NAME_PLACEHOLDER', $Name)
    $Content = $Content.Replace('__AI_AGENT_NAME__', $Name)
    $Content = $Content.Replace('__AI_AGENT_DISPLAY__', $Display)
    if ($Content -match '__GOV_PATH__|__AI_AGENT_') {
        Log-Error 'Postcondición incumplida: quedaron placeholders sin sustituir'
        throw 'Unsubstituted placeholders'
    }
    return $Content
}

# ==============================================================================
# MCP BINARY (Pilar 10: fail-fast + hash opcional)
# ==============================================================================
function Resolve-McpBinary {
    $cmd = Get-Command -Name 'codebase-memory-mcp' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path (Join-Path $script:UserHome '.local/bin') 'codebase-memory-mcp'),
        '/usr/local/bin/codebase-memory-mcp',
        '/opt/homebrew/bin/codebase-memory-mcp',
        (Join-Path $script:UserHome 'AppData/Local/Programs/codebase-memory-mcp/codebase-memory-mcp')
    )
    foreach ($c in $candidates) {
        foreach ($ext in @('', '.exe', '.cmd', '.bat', '.ps1')) {
            $full = "$c$ext"
            if (Test-Path -Path $full -PathType Leaf) { return $full }
        }
    }
    return $null
}

$script:McpBinaryPath = Resolve-McpBinary
if (-not $script:McpBinaryPath) {
    $script:McpBinaryPath = Join-Path (Join-Path $script:UserHome '.local/bin') 'codebase-memory-mcp'
    if ($AllowMissingMcp) {
        Log-Warn 'Binario MCP ausente; se despliega la config por -AllowMissingMcp'
    } else {
        Log-Error "Binario 'codebase-memory-mcp' no encontrado. Instálalo o usa -AllowMissingMcp"
        exit 1
    }
}
$expectedHash = [Environment]::GetEnvironmentVariable('AI_MCP_SHA256')
if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
    if (-not (Test-Path -LiteralPath $script:McpBinaryPath -PathType Leaf)) {
        Log-Error 'No se puede verificar el hash del MCP: binario inexistente'
        exit 1
    }
    $actualHash = (Get-FileHash -LiteralPath $script:McpBinaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
        Log-Error "Hash del MCP no coincide (AI-BOM): esperado $expectedHash, obtenido $actualHash"
        exit 1
    }
    $mcpVersion = [Environment]::GetEnvironmentVariable('AI_MCP_VERSION')
    Log-Info "MCP verificado por SHA-256 (versión $(if ($mcpVersion) { $mcpVersion } else { 'sin especificar' }))"
} elseif (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('AI_MCP_VERSION'))) {
    Log-Warn 'MCP versión declarada sin hash; AI-BOM incompleto'
}

# ==============================================================================
# ESTADO, DbC Y ESCRITURA (Pilares 16, 19)
# ==============================================================================
function Test-IsManaged {
    param([string]$Path)
    if (-not (Test-Path $script:StateFile)) { return $false }
    $lines = @(Get-Content -Path $script:StateFile -Encoding UTF8 -ErrorAction SilentlyContinue)
    return ($lines -contains $Path)
}
function Record-Managed {
    param([string]$Path)
    if ($DryRun) { return }
    if (-not (Test-Path $script:StateDir)) { New-Item -ItemType Directory -Force -Path $script:StateDir | Out-Null }
    if (-not (Test-Path $script:StateFile)) { [System.IO.File]::WriteAllText($script:StateFile, '', $script:Utf8NoBom) }
    if (-not (Test-IsManaged $Path)) {
        [System.IO.File]::AppendAllText($script:StateFile, "$Path`n", $script:Utf8NoBom)
    }
}
function Unrecord-Managed {
    param([string]$Path)
    if (-not (Test-Path $script:StateFile)) { return }
    $lines = @(Get-Content -Path $script:StateFile -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -ne $Path })
    [System.IO.File]::WriteAllLines($script:StateFile, [string[]]$lines, $script:Utf8NoBom)
}
function Normalize-FullPath {
    param([string]$Path)
    try { return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/') }
    catch { return $Path.TrimEnd('\', '/') }
}
function Test-UnderManagedRoots {
    param([string]$Path)
    $targetNorm = Normalize-FullPath $Path
    foreach ($r in @($script:OpenCodeRoot, $script:GeminiRoot, $script:ClaudeRoot)) {
        $rootNorm = Normalize-FullPath $r
        $p1 = $rootNorm + [System.IO.Path]::DirectorySeparatorChar
        $p2 = $rootNorm + '/'
        if ($targetNorm.StartsWith($p1, [System.StringComparison]::OrdinalIgnoreCase) -or
            $targetNorm.StartsWith($p2, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}
function Assert-UnderManagedRoots {
    param([string]$Path)
    if (-not (Test-UnderManagedRoots $Path)) {
        Log-Error "Precondición incumplida: ruta fuera de los roots gestionados: $Path"
        return $false
    }
    return $true
}
function Test-Abort {
    if (Test-Path -LiteralPath $script:AbortFile) {
        Log-Error "Kill switch activo ($($script:AbortFile)); abortando despliegue"
        return $false
    }
    return $true
}

$script:RollbackEntries = New-Object System.Collections.ArrayList

function Write-FileAtomic {
    param([string]$Path, [string]$Content)
    # Precondiciones (DbC).
    if ([string]::IsNullOrWhiteSpace($Path)) { Log-Error 'Precondición incumplida: path vacío'; return $false }
    if ([string]::IsNullOrWhiteSpace($Content)) { Log-Error "Precondición incumplida: contenido vacío para $Path"; return $false }
    if (-not (Assert-UnderManagedRoots $Path)) { return $false }
    if (-not (Test-Abort)) { return $false }

    $Content = $Content -replace "`r`n", "`n"
    $Content = $Content -replace "`r",   "`n"
    if (-not $Content.EndsWith("`n")) { $Content = "$Content`n" }

    if ($DryRun) {
        $byteCount = [System.Text.Encoding]::UTF8.GetByteCount($Content)
        Log-Dry ("Escribiría {0} bytes -> {1}" -f $byteCount, $Path)
        return $true
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    if ((Test-Path $Path) -and -not (Test-IsManaged $Path) -and -not $Force) {
        Log-Error "Rechazo sobrescribir archivo ajeno (sin marker): $Path"
        return $false
    }

    $backup = $null
    if ((Test-Path $Path) -and -not $NoBackup) {
        $backup = "$Path.bak.$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID"
        try {
            Copy-Item -Path $Path -Destination $backup -Force -ErrorAction Stop
            Log-Info "Backup: $backup"
        } catch {
            Log-Warn "No se pudo crear backup de $Path : $_"
            $backup = $null
        }
    }
    [void]$script:RollbackEntries.Add([pscustomobject]@{ Path = $Path; Backup = $backup })

    $tmpName = ".$(Split-Path -Leaf $Path).tmp.$([System.IO.Path]::GetRandomFileName())"
    $tmp = Join-Path $dir $tmpName
    $recoveryTmp = Join-Path $dir ".$(Split-Path -Leaf $Path).prev.$([System.IO.Path]::GetRandomFileName())"
    $hadExisting = Test-Path -LiteralPath $Path
    $movedToRecovery = $false
    try {
        [System.IO.File]::WriteAllText($tmp, $Content, $script:Utf8NoBom)
        if ($hadExisting) {
            [System.IO.File]::Move($Path, $recoveryTmp)
            $movedToRecovery = $true
        }
        [System.IO.File]::Move($tmp, $Path)
        if ($movedToRecovery -and (Test-Path -LiteralPath $recoveryTmp)) {
            Remove-Item -LiteralPath $recoveryTmp -Force -ErrorAction SilentlyContinue
        }
        # Postcondición (DbC).
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or ((Get-Item -LiteralPath $Path).Length -eq 0)) {
            throw "Postcondición incumplida: $Path no existe o está vacío"
        }
        Log-Info "Escrito: $Path"
        Record-Managed $Path
        return $true
    } catch {
        if ($movedToRecovery -and (Test-Path -LiteralPath $recoveryTmp) -and -not (Test-Path -LiteralPath $Path)) {
            try { [System.IO.File]::Move($recoveryTmp, $Path) } catch { }
        }
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        Log-Error "Fallo al escribir $Path : $_"
        return $false
    }
}

function Invoke-Rollback {
    foreach ($entry in $script:RollbackEntries) {
        try {
            if ($entry.Backup -and (Test-Path -LiteralPath $entry.Backup)) {
                Copy-Item -LiteralPath $entry.Backup -Destination $entry.Path -Force
            } else {
                Remove-Item -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue
            }
            Unrecord-Managed $entry.Path
            Log-Warn "Rollback aplicado: $($entry.Path)"
        } catch {
            Log-Error "No se pudo revertir $($entry.Path): $_"
        }
    }
    $script:RollbackEntries.Clear()
}

function Test-JsonSyntax {
    param([string]$Raw)
    # ConvertFrom-Json usa un diccionario case-insensitive y rechaza JSON válido
    # con claves que solo difieren en mayúsculas (*secret* / *Secret* / *SECRET*).
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        try { $null = $Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop; return $true }
        catch { return $false }
    }
    try {
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $serializer.MaxJsonLength = [int]::MaxValue
        $null = $serializer.DeserializeObject($Raw)
        return $true
    } catch {
        try { $null = $Raw | ConvertFrom-Json -ErrorAction Stop; return $true }
        catch { return ($_.Exception.Message -match 'duplicat|different cas|casing') }
    }
}

function Validate-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { Log-Warn "JSON no encontrado: $Path"; return $false }
    try {
        $raw = Get-Content -Path $Path -Raw -Encoding UTF8
        if (-not (Test-JsonSyntax -Raw $raw)) { throw 'Sintaxis JSON inválida' }
        Log-Info "JSON OK: $Path"
        return $true
    } catch {
        Log-Error "JSON INVÁLIDO: $Path - $_"
        return $false
    }
}

# ==============================================================================
# GATE HUMANO (Pilar 4)
# ==============================================================================
function Require-HumanGate {
    if ($DryRun) { return $true }
    if ($Yes) { Write-AuditEvent 'APPROVAL' 'Aprobación declarada mediante -Yes'; return $true }
    if ([Environment]::UserInteractive -and $Host.UI.RawUI -and -not $Host.Runspace.IsRemote) {
        $answer = Read-Host "Va a desplegar gobernanza en: $Targets. ¿Continuar? [s/N]"
        if ($answer -match '^[sSyY]$|^si$|^SI$|^Si$') {
            Write-AuditEvent 'APPROVAL' 'Aprobación interactiva confirmada'
            return $true
        }
        Write-AuditEvent 'ABORT' 'Gate humano rechazado'
        return $false
    }
    Log-Error 'Se requiere confirmación humana: usa -Yes en sesiones no interactivas'
    return $false
}

# ==============================================================================
# UNINSTALL
# ==============================================================================
function Invoke-Uninstall {
    if (-not (Test-Path $script:StateFile)) {
        Log-Warn "Sin state file en $($script:StateFile); nada que desinstalar."
        return
    }
    Log-Info "Desinstalando archivos registrados en $($script:StateFile)"
    $lines = @(Get-Content -Path $script:StateFile -Encoding UTF8 -ErrorAction SilentlyContinue)
    foreach ($path in $lines) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        if (-not (Test-UnderManagedRoots $path)) {
            Log-Warn "Ruta fuera de los roots gestionados; se omite: $path"
            continue
        }
        if (-not (Test-Path $path)) { Log-Warn "No existe (¿ya eliminado?): $path"; continue }
        if ($DryRun) { Log-Dry "Eliminaría: $path" }
        else { Remove-Item -Force -Path $path -ErrorAction SilentlyContinue; Log-Info "Eliminado: $path" }
    }
    $dirs = @(
        $script:OpenCodeCmds, $script:OpenCodeDocs, $script:OpenCodeRoot,
        $script:AntiWorkflows, $script:AntiRoot, $script:GeminiDocs, $script:GeminiRoot,
        $script:ClaudeDocs, $script:ClaudeRoot
    )
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { continue }
        if ($DryRun) { Log-Dry "Intentaría eliminar (solo si vacío): $d" }
        else {
            try {
                $items = @(Get-ChildItem -Force -Path $d -ErrorAction SilentlyContinue)
                if ($items.Count -eq 0) { Remove-Item -Force -Path $d -ErrorAction Stop; Log-Info "Directorio vacío eliminado: $d" }
            } catch { }
        }
    }
    if (-not $DryRun) {
        Remove-Item -Force -Path $script:StateFile -ErrorAction SilentlyContinue
        try {
            $items = @(Get-ChildItem -Force -Path $script:StateDir -ErrorAction SilentlyContinue)
            if ($items.Count -eq 0) { Remove-Item -Force -Path $script:StateDir -ErrorAction SilentlyContinue }
        } catch { }
    }
    Log-Info 'Desinstalación completa.'
}

# ==============================================================================
# DEPLOY PER TARGET
# ==============================================================================
function Write-JsonConfigs {
    $mcpJson      = ConvertTo-Json -InputObject $script:McpBinaryPath -Compress
    $agentsMdJson = ConvertTo-Json -InputObject (Join-Path $script:OpenCodeRoot 'AGENTS.md') -Compress
    $govMdJson    = ConvertTo-Json -InputObject $script:GovOpenCode -Compress
    $cfg = @"
{
  "`$schema": "https://opencode.ai/config.json",
  "instructions": [
    $agentsMdJson,
    $govMdJson
  ],
  "share": "disabled",
  "autoupdate": false,
  "mcp": {
    "codebase-memory-mcp": {
      "enabled": true,
      "type": "local",
      "command": [
        $mcpJson
      ]
    }
  },
  "permission": {
    "read": {
      "*": "allow",
      "*.env": "ask",
      "*.env.*": "ask",
      "*secret*": "ask",
      "*Secret*": "ask",
      "*SECRET*": "ask",
      "*token*": "ask",
      "*credential*": "ask",
      "*Credential*": "ask",
      "*.pem": "deny",
      "*.key": "deny",
      "*.pfx": "deny",
      "*.p12": "deny"
    },
    "edit": "ask",
    "webfetch": "ask",
    "bash": {
      "*": "ask",
      "git status": "allow",
      "git status *": "allow",
      "git diff *": "allow",
      "git log *": "allow",
      "git branch": "allow",
      "git branch *": "allow",
      "git fetch *": "allow",
      "git add *": "allow",
      "git commit *": "allow",
      "git push": "allow",
      "git push -u origin *": "allow",
      "gh pr *": "allow",
      "gh repo view *": "allow",
      "gh auth status": "allow",
      "ls *": "allow",
      "dir *": "allow",
      "Get-ChildItem *": "allow",
      "find *": "allow",
      "pytest *": "allow",
      "go test *": "allow",
      "dotnet test *": "allow",
      "npm test *": "allow",
      "bash tests/*": "allow",
      "rm -rf *": "deny",
      "rm -fr *": "deny",
      "rm -Rf *": "deny",
      "rm -rF *": "deny",
      "rm --recursive *": "deny",
      "Remove-Item * -Recurse *": "deny",
      "git push --force *": "deny",
      "git push -f *": "deny",
      "git reset --hard *": "deny",
      "git clean -fdx *": "deny",
      "gh auth token*": "deny",
      "gh repo delete*": "deny",
      "gh secret *": "deny",
      "gh ssh-key *": "deny",
      "gh gpg-key *": "deny",
      "curl *": "ask",
      "wget *": "ask",
      "Invoke-WebRequest *": "ask",
      "Invoke-RestMethod *": "ask",
      "docker rm *": "deny",
      "docker rmi *": "deny",
      "docker container rm *": "deny",
      "docker volume rm *": "deny",
      "docker system prune *": "deny"
    }
  }
}
"@
    return Write-FileAtomic -Path (Join-Path $script:OpenCodeRoot 'opencode.json') -Content $cfg
}

function Deploy-OpenCode {
    Log-Info '=== Target: OpenCode ==='
    $gov = [System.IO.File]::ReadAllText((Join-Path $script:ContentDir 'AI_GOVERNANCE.md'), $script:Utf8NoBom)
    if (-not (Write-FileAtomic -Path $script:GovOpenCode -Content $gov)) { return $false }
    $a = Apply-AgentSubs -Content $script:AgentsTemplate -Name $script:AgentNameOpenCode -Display $script:AgentDispOpenCode -GovPath $script:GovOpenCode
    if (-not (Write-FileAtomic -Path (Join-Path $script:OpenCodeRoot 'AGENTS.md') -Content $a)) { return $false }
    if (-not (Write-FileAtomic -Path (Join-Path $script:OpenCodeCmds 'audit-governance.md') -Content $script:AuditPrompt)) { return $false }
    $c = Apply-AgentSubs -Content $script:CommitTemplate -Name $script:AgentNameOpenCode -Display $script:AgentDispOpenCode -GovPath $script:GovOpenCode
    if (-not (Write-FileAtomic -Path (Join-Path $script:OpenCodeCmds 'commit.md') -Content $c)) { return $false }
    $p = Apply-AgentSubs -Content $script:PrTemplate -Name $script:AgentNameOpenCode -Display $script:AgentDispOpenCode -GovPath $script:GovOpenCode
    if (-not (Write-FileAtomic -Path (Join-Path $script:OpenCodeCmds 'pr.md') -Content $p)) { return $false }
    return (Write-JsonConfigs)
}

function Deploy-Gemini {
    Log-Info '=== Target: Gemini / Antigravity ==='
    $gov = [System.IO.File]::ReadAllText((Join-Path $script:ContentDir 'AI_GOVERNANCE.md'), $script:Utf8NoBom)
    if (-not (Write-FileAtomic -Path $script:GovGemini -Content $gov)) { return $false }
    $a = Apply-AgentSubs -Content $script:AgentsTemplate -Name $script:AgentNameGemini -Display $script:AgentDispGemini -GovPath $script:GovGemini
    if (-not (Write-FileAtomic -Path (Join-Path $script:GeminiRoot 'GEMINI.md') -Content $a)) { return $false }
    if (-not (Write-FileAtomic -Path (Join-Path $script:AntiWorkflows 'audit-governance.md') -Content $script:AuditPrompt)) { return $false }
    $c = Apply-AgentSubs -Content $script:CommitTemplate -Name $script:AgentNameGemini -Display $script:AgentDispGemini -GovPath $script:GovGemini
    if (-not (Write-FileAtomic -Path (Join-Path $script:AntiWorkflows 'commit.md') -Content $c)) { return $false }
    $p = Apply-AgentSubs -Content $script:PrTemplate -Name $script:AgentNameGemini -Display $script:AgentDispGemini -GovPath $script:GovGemini
    if (-not (Write-FileAtomic -Path (Join-Path $script:AntiWorkflows 'pr.md') -Content $p)) { return $false }
    $mcpJson = ConvertTo-Json -InputObject $script:McpBinaryPath -Compress
    $cfg = @"
{
  "mcpServers": {
    "codebase-memory-mcp": {
      "command": $mcpJson,
      "args": []
    }
  }
}
"@
    return (Write-FileAtomic -Path (Join-Path $script:AntiRoot 'mcp_config.json') -Content $cfg)
}

function Deploy-Claude {
    Log-Info '=== Target: Claude Code ==='
    $gov = [System.IO.File]::ReadAllText((Join-Path $script:ContentDir 'AI_GOVERNANCE.md'), $script:Utf8NoBom)
    if (-not (Write-FileAtomic -Path $script:GovClaude -Content $gov)) { return $false }
    $a = Apply-AgentSubs -Content $script:AgentsTemplate -Name $script:AgentNameClaude -Display $script:AgentDispClaude -GovPath $script:GovClaude
    return (Write-FileAtomic -Path (Join-Path $script:ClaudeRoot 'CLAUDE.md') -Content $a)
}

# ==============================================================================
# MAIN
# ==============================================================================
function Invoke-Main {
    Log-Info "setup-ai-governance.ps1 v$($script:ScriptVersion)"
    Log-Info "Correlation ID: $($script:CorrelationId)"
    Log-Info 'HOME: <HOME>'
    Log-Info "Targets: $($script:TargetList -join ',')"
    Log-Info "MCP binary: $($script:McpBinaryPath)"
    Log-Info "Dry-run: $($DryRun)  Force: $($Force)  No-backup: $($NoBackup)  Uninstall: $($Uninstall)  Yes: $($Yes)"
    Log-Info "Log: $($script:LogFile)"

    if ($Uninstall) { Invoke-Uninstall; return $true }
    if (-not (Require-HumanGate)) { return $false }

    if (Test-TargetEnabled 'opencode') {
        if (-not (Test-Abort)) { Invoke-Rollback; return $false }
        if (-not (Deploy-OpenCode)) { Invoke-Rollback; return $false }
    }
    if (Test-TargetEnabled 'gemini') {
        if (-not (Test-Abort)) { Invoke-Rollback; return $false }
        if (-not (Deploy-Gemini)) { Invoke-Rollback; return $false }
    }
    if (Test-TargetEnabled 'claude') {
        if (-not (Test-Abort)) { Invoke-Rollback; return $false }
        if (-not (Deploy-Claude)) { Invoke-Rollback; return $false }
    }

    if (-not $DryRun) {
        $ok = $true
        if (Test-TargetEnabled 'opencode') { if (-not (Validate-JsonFile (Join-Path $script:OpenCodeRoot 'opencode.json'))) { $ok = $false } }
        if (Test-TargetEnabled 'gemini')   { if (-not (Validate-JsonFile (Join-Path $script:AntiRoot 'mcp_config.json'))) { $ok = $false } }
        if ($ok) {
            Log-Info 'Validación final: OK'
            $script:RollbackEntries.Clear()
        } else {
            Log-Error 'Validación final: FALLÓ (revisa el log)'
            Invoke-Rollback
            return $false
        }
    }

    Write-Host @"

🎉 [COMPLETADO] Marco de Gobernanza de IA v$($script:ScriptVersion) desplegado.

📂 Rutas:
   - OpenCode:            $($script:OpenCodeRoot)
   - Gemini/Antigravity:  $($script:GeminiRoot)
   - Claude Code:         $($script:ClaudeRoot)

📋 State:  $($script:StateFile)
📋 Log:    $($script:LogFile)

💡 Reinicia tu terminal/editor para que los agentes carguen las nuevas reglas.
   Desinstalar:  $($script:ScriptName) -Uninstall
   Simular:      $($script:ScriptName) -DryRun
"@
    return $true
}

try {
    if (-not (Invoke-Main)) { exit 1 }
    exit 0
} catch {
    Write-AuditEvent 'ERROR' "Fallo no controlado: $_"
    Write-Error $_
    exit 1
}
