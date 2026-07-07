"""
verify_v03.py
Verifica la integridad del release v0.3 de CBIB_PatchlinerTools.
Uso: python verify_v03.py [ruta_a_v0.3]
     Si no se pasa ruta, usa el directorio actual.
"""

import os, re, sys
from pathlib import Path

# ── Configuración ────────────────────────────────────────────────────────────

REPO_ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
V03       = REPO_ROOT / "v0.3"

# Módulos esperados en v0.3/
EXPECTED_FILES = [
    "PLT_Amplitude.ipf",
    "PLT_Common.ipf",
    "PLT_Core.ipf",
    "PLT_Menus.ipf",
    "PLT_NMExport.ipf",
    "PLT_Utils.ipf",
    "PLT_IVCurves.ipf",
    "PLT_Kinetics.ipf",
]

# Referencias antiguas que NO deben aparecer en ningún PLT_*.ipf
BANNED_REFS = [
    "Analysis_Common",
    "Analysis_Menus",
    "Analysis_Utils",
    "Analysis_Core",
    "Analysis_Amplitude",
    "Analysis_NMExport",
    "Analysis_Ramp",
    "Analysis_IV.ipf",
]

# Funciones que deben estar en el módulo correcto
OWNERSHIP = {
    "PLT_Utils.ipf":     ["SubtractBaseline", "ListSubfolders", "Extract2DColumn",
                           "place_cursors", "place_cursor", "StoreCursorWavePath",
                           "EnsureGraphWindow", "AppendWaveListToGraph",
                           "AppendXYWaveListToGraph", "CheckDataFolder",
                           "nvar_storer", "svar_storer", "ParentFolder",
                           "FolderNameFromPath", "LogInfo", "LogWarn", "LogError",
                           "LogButtonProc"],    # defined in Utils — called as proc= in Menus
    "PLT_Common.ipf":    ["sorting_hat", "first_phase", "second_phase",
                           "prefix_detector", "pasivas", "expFitRsCm"],
    "PLT_Core.ipf":      ["plot_raw_panel", "plot_stim", "plot_trace",
                           "tempresponse", "IV_graph", "AnalizarIVporCanal"],
    "PLT_Amplitude.ipf": ["plot_amp_analysis", "MakeTwoPanels_plot_amp",
                           "findamp", "amp_saver", "amp_retreiver",
                           "CursorMovedHook", "AmpButtonProc"],
    "PLT_NMExport.ipf":  ["ExportChannelToNM", "NMExport_InitFolder",
                           "NMExport_CopyWaves"],
    "PLT_Menus.ipf":     ["start_panels", "TabProc",
                           "menu_tempresponse", "menu_leaksustraction"],
}

# Funciones reutilizables que deben ser LLAMADAS (no definidas) en otros módulos
REUSE_CHECKS = [
    # (función,           módulo_que_debe_llamarla,   módulo_donde_está_definida)
    ("SubtractBaseline",  "PLT_Core.ipf",             "PLT_Utils.ipf"),
    # PLT_Common does NOT call SubtractBaseline — pasivas() receives
    # pre-corrected waves from its callers (tempresponse, AnalizarIVporCanal).
    # Drift correction is the caller's responsibility, not pasivas()'s.
    ("ListSubfolders",    "PLT_Common.ipf",            "PLT_Utils.ipf"),
    ("ListSubfolders",    "PLT_NMExport.ipf",          "PLT_Utils.ipf"),
    ("place_cursors",     "PLT_Core.ipf",              "PLT_Utils.ipf"),
    ("place_cursors",     "PLT_Amplitude.ipf",         "PLT_Utils.ipf"),
    ("Extract2DColumn",   "PLT_Core.ipf",              "PLT_Utils.ipf"),
    ("pasivas",           "PLT_Core.ipf",              "PLT_Common.ipf"),
    ("CheckDataFolder",   "PLT_Amplitude.ipf",         "PLT_Utils.ipf"),
    ("StoreCursorWavePath","PLT_Core.ipf",             "PLT_Utils.ipf"),
    ("EnsureGraphWindow", "PLT_Core.ipf",              "PLT_Utils.ipf"),
]

# Funciones que NO deben estar duplicadas entre módulos
NO_DUPLICATES = [
    "SubtractBaseline", "ListSubfolders", "Extract2DColumn",
    "place_cursors", "place_cursor", "StoreCursorWavePath",
    "pasivas", "expFitRsCm", "LogInfo", "LogWarn", "LogError",
]

# ── Helpers ──────────────────────────────────────────────────────────────────

PASS = "\033[92m✓\033[0m"
FAIL = "\033[91m✗\033[0m"
WARN = "\033[93m⚠\033[0m"

errors = 0
warnings = 0

def ok(msg):
    print(f"  {PASS} {msg}")

def fail(msg):
    global errors
    errors += 1
    print(f"  {FAIL} {msg}")

def warn(msg):
    global warnings
    warnings += 1
    print(f"  {WARN} {msg}")

def read(fname):
    p = V03 / fname
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

def defined_functions(content):
    """Extrae nombres de funciones definidas. Soporta tres formas de Igor Pro:
       - Function name(           → función estándar
       - Function/S name(         → función con flag de tipo (/S, /WAVE, etc.)
       - Function [Variable ...] name(  → función con múltiples valores de retorno
    """
    # Forma estándar: Function[/flag] name(
    standard = re.findall(r'^Function(?:/\w+)?\s+(\w+)\s*\(', content, re.MULTILINE)
    # Multi-return: Function [...] name(
    multi    = re.findall(r'^Function\s+\[.*?\]\s+(\w+)\s*\(', content, re.MULTILINE)
    return set(standard) | set(multi)

def called_functions(content):
    """Extrae nombres de funciones llamadas (heurístico: word seguido de '(')."""
    return set(re.findall(r'\b(\w+)\s*\(', content))

# ── Cargar contenidos ────────────────────────────────────────────────────────

contents = {}
for fname in EXPECTED_FILES:
    contents[fname] = read(fname)

# ── CHECK 1: Archivos presentes ───────────────────────────────────────────────

print("\n── 1. Archivos en v0.3/ ─────────────────────────────────────────────")
for fname in EXPECTED_FILES:
    if (V03 / fname).exists():
        ok(fname)
    else:
        fail(f"{fname} — NO ENCONTRADO")

# ── CHECK 2: Sin referencias a nombres Analysis_* ────────────────────────────

print("\n── 2. Sin referencias a nombres Analysis_* ──────────────────────────")
for fname, content in contents.items():
    found = [r for r in BANNED_REFS if r in content]
    if found:
        fail(f"{fname}: referencias antiguas: {found}")
    else:
        ok(fname)

# ── CHECK 3: Funciones en módulo correcto ─────────────────────────────────────

print("\n── 3. Funciones en módulo correcto ──────────────────────────────────")
for fname, funcs in OWNERSHIP.items():
    content = contents.get(fname, "")
    defined = defined_functions(content)
    missing = [f for f in funcs if f not in defined]
    if missing:
        fail(f"{fname}: funciones no encontradas: {missing}")
    else:
        ok(f"{fname} ({len(funcs)} funciones OK)")

# ── CHECK 4: Sin duplicados ───────────────────────────────────────────────────

print("\n── 4. Sin funciones duplicadas ──────────────────────────────────────")
for func in NO_DUPLICATES:
    owners = [fname for fname, c in contents.items() if func in defined_functions(c)]
    if len(owners) > 1:
        fail(f"{func} definida en múltiples módulos: {owners}")
    elif len(owners) == 0:
        warn(f"{func} no encontrada en ningún módulo")
    else:
        ok(f"{func} → {owners[0]}")

# ── CHECK 5: Reutilización de helpers ─────────────────────────────────────────

print("\n── 5. Helpers reutilizables correctamente llamados ──────────────────")
for func, caller_file, def_file in REUSE_CHECKS:
    caller_content = contents.get(caller_file, "")
    # Verificar que está llamada pero NO definida en el caller
    called = func in called_functions(caller_content)
    defined = func in defined_functions(caller_content)
    if defined:
        fail(f"{func}: definida en {caller_file} — debería estar solo en {def_file}")
    elif called:
        ok(f"{func} llamada desde {caller_file} (definida en {def_file})")
    else:
        warn(f"{func} no encontrada en {caller_file} — ¿es necesaria?")

# ── CHECK 6: Pragmas en todos los módulos ─────────────────────────────────────

print("\n── 6. Pragmas en todos los módulos ──────────────────────────────────")
for fname, content in contents.items():
    has_enc  = '#pragma TextEncoding' in content
    has_rtg  = '#pragma rtGlobals'    in content
    if has_enc and has_rtg:
        ok(fname)
    else:
        missing_p = []
        if not has_enc: missing_p.append("TextEncoding")
        if not has_rtg: missing_p.append("rtGlobals")
        fail(f"{fname}: faltan pragmas: {missing_p}")

# ── Resumen ───────────────────────────────────────────────────────────────────

print("\n─────────────────────────────────────────────────────────────────────")
if errors == 0 and warnings == 0:
    print(f"  {PASS} Todo OK — v0.3 lista para el PR")
elif errors == 0:
    print(f"  {WARN} {warnings} advertencia(s) — revisar antes del PR")
else:
    print(f"  {FAIL} {errors} error(s), {warnings} advertencia(s) — corregir antes del PR")
print()
