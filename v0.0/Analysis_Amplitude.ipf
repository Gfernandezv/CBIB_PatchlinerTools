#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

//====================================================
//   AMPLITUDE ANALYSIS (Shared module)
//====================================================

// ------------------------------------------------------------
// Function: plot_amp
// Purpose : Displays peak amplitude waves from the Analysis
//           folder using a three-panel layout (3 fit modes).
// Inputs  : mode - display mode: "raw", "norm", or "smth"
// Notes   : Mode is not exposed in the panel; can be called
//           manually for debugging.
// ------------------------------------------------------------
Function plot_amp(mode)
    String mode  // raw, norm, smth

    String current_folder  = GetDataFolder(1)
    String trace_folder    = current_folder + "Analysis:"
    String packages_folder = current_folder + "Packages:"

    String graph_mode = StrVarOrDefault((packages_folder+"graph_mode"), mode)
    String windows_name = "Norm_graph", title
    Variable i, col_index
    NVAR/Z temp = $(packages_folder+"ramp_temp")
    SetDataFolder trace_folder

    String y_traces, y_wave_name, wbase_name = ("*_fitpeak_"+num2str(temp))

    strswitch (mode)
        case "raw":
            y_traces    = WaveList((wbase_name), ";", "")
            y_wave_name = StringFromList(0, y_traces)
            title       = "Raw graphs"
            break

        case "norm":
            y_traces    = WaveList((wbase_name+"_norm"), ";", "")
            y_wave_name = StringFromList(0, y_traces)
            title       = "Norm graphs"
            break

        case "smth":
            y_traces    = WaveList((wbase_name+"_norm_smth"), ";", "")
            y_wave_name = StringFromList(0, y_traces)
            title       = "Smooth graphs"
            break
    endswitch

    Wave w = $y_wave_name
    MakeTwoPanels_plot_amp(w, title)

    SetDataFolder current_folder
End


// ------------------------------------------------------------
// Function: MakeTwoPanels_plot_amp
// Purpose : Creates a three-panel figure showing all fit modes
//           for a 2D peak amplitude wave.
// Inputs  : w     - 2D wave with columns [0]=mode0, [1]=mode1, [2]=mode2
//           title - window title string
// ------------------------------------------------------------
Function MakeTwoPanels_plot_amp(w, title)
    Wave w
    String title

	// Extract columns from 2D wave
    Duplicate/O/R=[][0] w w_col0
    Duplicate/O/R=[][1] w w_col1
    Duplicate/O/R=[][2] w w_col2
    
    // Store w_col2 path for CursorMovedHook
    NewDataFolder/O root:Packages
    String/G root:Packages:amp2_wave_path = GetWavesDataFolder(w_col2, 2)

    if (WinType("Fig1"))    // already exists — close and recreate
        KillWindow/Z Fig1
    endif

    NewPanel/K=1/W=(753,442,2063,842) as title
    DoWindow/C Fig1

    DrawText 180,  30, "Fit mode 0"
    DrawText 545,  30, "Fit mode 2"
    //DrawText 1025, 30, "Fit mode 2"

    Display/HOST=Fig1/N=Amp0/W=(10,50,410,350)   w_col0
    Display/HOST=Fig1/N=Amp2/W=(430,50,830,350)  w_col2
    //edit
    //Display/HOST=Fig1/N=Amp2/W=(850,50,1250,350) w_col2
    place_cursors("Fig1#Amp2", w_col2, 0.1, 0.9)
	 DoUpdate
	 
   
    ShowInfo/W=Fig1
	 SetWindow Fig1#Amp2, hook(cursor)=CursorMovedHook

    Button store_amp, pos={1139,361}, size={100,20}, title="Store amp", proc=AmpButtonProc
End


// ------------------------------------------------------------
// Function: AmpButtonProc
// Purpose : Button handler — reads cursor positions and
//           triggers amplitude storage via findamp().
// ------------------------------------------------------------
Function AmpButtonProc(ctrlName) : ButtonControl
    String ctrlName

    Variable x_a = xcsr(A, "Fig1#Amp2")
    Variable x_b = xcsr(B, "Fig1#Amp2")
    
    if (numtype(x_a) == 2 || numtype(x_b) == 2)
        LogWarn("AmpButtonProc: cursors not set on Fig1#Amp2")
        return 0
    endif

    Variable A_value = vcsr(A, "Fig1#Amp2")

    SVAR/Z path = root:Packages:amp2_wave_path
    Wave/Z w = $path
    Variable max_val = WaveMax(w, min(x_a,x_b), max(x_a,x_b))

    findamp(A_value, max_val,"Fig1")
End


// ------------------------------------------------------------
// Function: findamp
// Purpose : Reads cursor A and B values, stores them as
//           amplitude measurements via data_saver().
// Inputs  : amp_ini - cursor A value (baseline amplitude)
//           amp_fin - cursor B value (peak amplitude)
// ------------------------------------------------------------
Function findamp(amp_ini, amp_fin, host)
    Variable amp_ini, amp_fin
	 String host
	 
    String current_folder  = GetDataFolder(1)
    String analysis_folder = current_folder + "Analysis"
    String packages        = current_folder + "Packages"
    SetDataFolder $packages

    SVAR/Z chan   = chanexp
    NVAR/Z temp   = ramp_temp
    amp_ini 			= nvar_storer("amp_ini", amp_ini, current_folder)
    amp_fin 		   = nvar_storer("amp_fin", amp_fin, current_folder)
	
    SVAR/Z traces_prefix = $(ParentFolder(GetDataFolder(1), 3)+"Packages:Wave_prefix")
    String mut_name = FolderNameFromPath(ParentFolder(GetDataFolder(1), 4))
    mut_name = ReplaceString("'", mut_name, "")
	print analysis_folder
    SetDataFolder(analysis_folder)
	
    data_saver(mut_name, traces_prefix, chan, amp_ini, 0, temp, host)
    data_saver(mut_name, traces_prefix, chan, amp_fin, 1, temp, host)
    data_saver(mut_name, traces_prefix, chan, (amp_fin-amp_ini), 2, temp, host)

    SetDataFolder(current_folder)
End


// ------------------------------------------------------------
// Function: data_saver
// Purpose : Stores an amplitude value in a 2D result wave
//           indexed by temperature and column.
// Inputs  : mut_name      - mutant/condition name
//           traces_prefix - wave prefix
//           chan          - channel name
//           max_amp       - amplitude value to store
//           col_index     - column index (0=ini, 1=fin, 2=delta)
//           temp          - temperature (°C)
// Notes   : Temperature axis: t0=20°C, dt=5°C, nT=6 points.
//           Result wave is created if it does not exist.
// ------------------------------------------------------------
Function data_saver(mut_name, traces_prefix, chan, max_amp, col_index, temp, host)
    String mut_name, traces_prefix, chan, host
    Variable max_amp, col_index, temp

    Variable nT  = 6
    Variable t0  = 20
    Variable dt  = 5
    Variable idx = round((temp - t0) / dt)

    // ---------------- VALIDATION ----------------
    if (idx < 0 || idx >= nT)
        LogError("data_saver: idx out of range: " + num2str(idx) + " temp=" + num2str(temp))
        return 0
    endif

    if (col_index < 0 || col_index >= 3)
        LogError("data_saver: col_index out of range: " + num2str(col_index))
        return 0
    endif
    // --------------------------------------------

    String maxwave_fullname = "'" + mut_name + "_" + traces_prefix + "_" + chan + "_Amp'"
    String maxwave_name     = (ParentFolder(GetDataFolder(1), 2) + maxwave_fullname)

    if (!WaveExists($maxwave_name))
        Make/O/N=(nT,3) $maxwave_name
        Wave maxwave = $maxwave_name
        maxwave = NaN
        SetScale/P x t0, dt, "°C", maxwave
    endif
    Wave maxwave = $maxwave_name
    maxwave[idx][col_index] = max_amp
    LogInfo("Saved: " + NameOfWave(maxwave) +\
            " idx:"   + num2str(idx)       +\
            " col:"   + num2str(col_index) +\
            " value:" + num2str(max_amp))

    if (!WinType("Tabla_max"))
        Edit/HOST=$host/K=1/N=$("Tabla_max")/W=(850,50,1300,350) maxwave.id
    else
        DoWindow/W=$host/F $("Tabla_max")
    endif

End


// ------------------------------------------------------------
// Function: CursorMovedHook
// Purpose : Captures cursor movement events from graph windows.
// ------------------------------------------------------------
Function CursorMovedHook(info)
    String info

    // Only act on cursors in Amp2
    String win_name = StringByKey("GRAPH", info, ":", ";")
    if (!stringmatch(win_name, "Amp2"))
        return 0
    endif

    // Recover w_col2 path
    SVAR/Z path = root:Packages:amp2_wave_path
    if (!SVAR_Exists(path))
        return 0
    endif
    Wave/Z w_col2 = $path
    if (!WaveExists(w_col2))
        return 0
    endif

    // Calculate max between cursors A and B
    Variable x_a    = xcsr(A, "Fig1#Amp2")
    Variable x_b    = xcsr(B, "Fig1#Amp2")
    
    if (numtype(x_a) == 2 || numtype(x_b) == 2)    // NaN = cursor not on graph
        return 0
    endif

    Variable maxVal = WaveMax(w_col2, min(x_a,x_b), max(x_a,x_b))
	
    // Update or create reference line wave
    String ref_path = path[0, strsearch(path, "w_col2", 0)-1] + "ref_line"
    Make/O/N=2 $ref_path
    Wave ref_line = $ref_path
    ref_line = maxVal
    SetScale/I x, min(x_a,x_b), max(x_a,x_b), ref_line

    // Append only if not already in graph
    String traceList = TraceNameList("Fig1#Amp2", ";", 1)
    
    Print "max value:", maxVal
    Print "net max value:", (abs(maxVal - w_col2[x_a]))
    
    if (strsearch(traceList, "ref_line", 0) < 0)
        Print "appending ref_line"
        AppendToGraph/W=Fig1#Amp2 ref_line
        ModifyGraph/W=Fig1#Amp2 lstyle(ref_line)=3, rgb(ref_line)=(0,0,65535)
    endif

End

// ------------------------------------------------------------
// Function: cursor_info_spliter
// Purpose : Parses cursor info string into name and index.
// ------------------------------------------------------------
Function [String val_name, String val_value] cursor_info_spliter(String expresion)

    String expr = "([[:alpha:]]+):([[:alpha:]]+)"
    String indicador, valor
    SplitString/E=(expr) expresion, indicador, valor

    return [indicador, valor]
End


// ------------------------------------------------------------
// Function: Include_generator
// Purpose : Generates an inclusion table for Q10/Arrhenius
//           analysis from a list of waves matching a genotype.
// Inputs  : folder   - data folder path
//           genotype - wave name prefix to match
// Outputs : 2D text wave Include[][0]=name, [][1]="0" (include)
// ------------------------------------------------------------
Function Include_generator(folder, genotype)
    String folder, genotype

    String list = WaveList((genotype+"*"), ";", "")
    Variable i

    Make/T/O/N=(ItemsInList(list),2) Include

    for (i = 0; i < ItemsInList(list); i += 1)
        Include[i][0] = StringFromList(i, list)
        Include[i][1] = "0"
    endfor

End


