{ ******************************************************************************
  * Description  : This Unit contains OC1 Pumping, Vent, Ror, Regen, Process sequence.
  * @ Project    : SP1301 (SFC)
  * @ Author     : Park Sang Soo.
  * @ Create     : 2011. 05. 12.
  * @ Last Update: 2013. 04. 15. KSY.
  ******************************************************************************* }

unit OC1ProcessUnit;

interface

uses
   Windows, Classes, Sysutils, Dialogs, SEPUnit, SEPDefineUnit, SEPGlobalUnit, MemoryMapUnit,
  BaseFunctionUnit;

Const
  MaxCoDep = 4;
  MaxCell = 6;
  MaxItem = 49;

  STEP_P_PROCESS_RecipeLoading         =  1;
  STEP_P_PROCESS_DoorCloseCheck        =  2;
  STEP_P_PROCESS_GateValveCloseCheck   =  3;
  STEP_P_PROCESS_VacuumCheck           =  4;
  STEP_P_PROCESS_GlassCheck            =  5;
  STEP_P_PROCESS_MainShutterClose      =  6;
  STEP_P_PROCESS_MaskChangePick        =  7;
  STEP_P_PROCESS_MaskChangePlace       =  8;
  STEP_P_PROCESS_Align                 =  9;
  STEP_P_PROCESS_AlignerRotation       =  10;
  STEP_P_PROCESS_CellProcessCheck      =  11;
  STEP_P_PROCESS_MainShutterOpen       =  12;
  STEP_P_PROCESS_ThicknessCheck        =  13;
  STEP_P_PROCESS_MainShutterCloseCheck =  14;
  STEP_P_PROCESS_CellAfterCheck        =  15;
  STEP_P_PROCESS_CellWaitTimeCheck     =  16;
  STEP_P_PROCESS_EndStepCheck          =  17;
  STEP_P_PROCESS_AlignerGlassLoad      =  18;
  STEP_P_PROCESS_ProcessEnd            =  19;

type
  TOC1Recipe = record
    TotalTime: Single; // Process Total Time.
    TotalStep, // Process Total Step.
    StepNum, // Process Current Step Number.
    CheckCount: Integer; // Alarm Time Check.

    // Recipe Item List.
    StepName: array [1 .. MaxItem] of String;
    MaskChangeChamber, MaskChangeID, TargetThickness, RateStableTime
      : array [1 .. MaxItem] of Single;
    UsedCell, SensorNo, CellRate, CellStandbyTemp,CellBotStandbyTemp, AfterProcess,
      DelayTime: array [1 .. MaxCoDep, 1 .. MaxItem] of Single;
    CellProgramNum, RampingNum, BotRampingNum: array [1 .. MaxCoDep, 1 .. MaxItem] of String;
    AlignUse, AlignXShift, AlignYShift: array [1 .. MaxItem] of Single;
  end;

  TCheckFlag = record
    StandByCount, StandByDelayTime, RateCount, ShutterOpenCount, AlignerCount, MainRateCount,
      CheckRateCount: Integer;
    IC5_Stop_Count, IC5_OFF_Line_Count, PowerCount, DepositCount, Cell_Sn_Fail_Count,
      Cell_Temp_Alarm_Count, Cell_Temp_Alarm_Count2, Source_Empty_Count
      : array [1 .. MaxCoDep] of Integer;
  end;

  TOC1Process = class(TBaseThread)
  private
    // Vacuum
    procedure P_VAC_Check;
    procedure P_VAC_End;

    // Vent
    procedure P_VENT_Check;
    procedure P_VENT_End;

    // Ror
    procedure P_ROR_Check;
    procedure P_ROR_End;

    // Regen
    procedure P_REGEN_Check;
    procedure P_REGEN_End;

    // Process
    procedure P_PROCESS_DoorCloseCheck;
    procedure P_PROCESS_GateValveCloseCheck;
    procedure P_PROCESS_VacuumCheck;
    procedure P_PROCESS_GlassCheck;
//    procedure P_PROCESS_SN_SWITCHING;
    procedure P_PROCESS_MainShutterClose;
    procedure P_PROCESS_MaskChangePick;
    procedure P_PROCESS_MaskChangePlace;
    procedure P_PROCESS_Align;
    procedure P_PROCESS_AlignerRotation;
    procedure P_PROCESS_CellProcessCheck;
    procedure P_PROCESS_MainShutterOpen;
    procedure P_PROCESS_ThicknessCheck;
    procedure P_PROCESS_MainShutterCloseCheck;
    procedure P_PROCESS_CellAfterCheck;
    procedure P_PROCESS_CellWaitTimeCheck;
    procedure P_PROCESS_EndStepCheck;
    procedure P_PROCESS_AlignerGlassLoad;
    procedure P_PROCESS_ProcessEnd;

    procedure P_PROCESS_RateCheck;
    procedure P_PROCESS_RateStabilityTime;
    function F_RATE_CHECK: Boolean;
    function F_MAIN_RATE_CHECK: Boolean;

    procedure F_CellRecipe;
    procedure F_ALL_CELL_SHUTTER(openclose: PChar);
    procedure F_ALL_PROCESS_CELL_SHUTTER(openclose: PChar);
    procedure F_PROCESS_ShutterCheck;
    function F_THICKNESS_CHECK: Boolean;
    procedure F_SOURCE_EMPTY_ALARM_CHECK;
    procedure F_DEPOSITION_ALARM_CHECK;
    procedure F_ALIGNER_ALARM_CHECK;
    procedure F_PROCESS_ALARM_CHECK;
    procedure F_PROCESS_HUNTING_CHECK;
    procedure F_POWER_ON_ALARM_CHECK;

  protected
    procedure Execute; override;

    procedure VacuumProgress;
    procedure VentProgress;
    procedure RorProgress;
    procedure RegenProgress;
    procedure ProcessProgress;

  public
    Pb: TOC1Recipe;
    PbCell: TCellRecipe;
    Check: TCheckFlag;
    FinalThickness: Single;
    DepoStartThickness, HostThickness: Single;
    OC123Cygnus: byte;
    szDegree: string;
    EventTime: Integer;

    CellTime: array [1 .. MaxCell] of Integer;
    CellFlag: array [1 .. MaxCell] of Boolean;
    RateFlag: array [1 .. MaxCell] of Boolean;

    procedure P_PROCESS_RecipeLoading(Path: string);
    // Recipe loading
    procedure ShowAlarm(Id: Integer); // Alarm.
    procedure AlarmAction(const AAction: string);
    // Alarm Action.
    procedure ActionList; // Alarm Action List.
    procedure EventLog(Msg: string; Mode: Char = 'U');
    // Event Logging.
    procedure AlarmPost;
    // Read Alarm Digital Channel. Alarm Action.
  end;

procedure CreateTOC1Process;
procedure FreeTOC1Process;

var
  OC1Process: TOC1Process;

implementation

uses
  {OC1AlignerUnit ,} TMMovingUnit, DigitalUnit, AnalogUnit, AlarmUnit, StringUnit;

procedure CreateTOC1Process;
begin
  OC1Process := TOC1Process.Create(False);
  OC1Process.module := _OC1;
  OC1Process.ModuleName := 'OC1';
end;

procedure FreeTOC1Process;
begin
  OC1Process.Terminate;
  OC1Process := nil;
end;

// ==============================================================================
// Execute
// ==============================================================================

procedure TOC1Process.Execute;
begin
  repeat
  begin
    strMode := mm.GetDigSetStrID(PM_MODE, module);
    strCtrl := mm.GetDigSetStrID(PM_CTRL, module);

    if (strCtrl = 'Abort') then
    begin
      AlarmAction('Abort');
    end;

    VacuumProgress;
    VentProgress;
    RorProgress;
    RegenProgress;
    ProcessProgress;

    AlarmPost;

    SLEEP(100);
  end;
  until Terminated;
end;

// ==============================================================================
// Alarm, Event...
// ==============================================================================

procedure TOC1Process.EventLog(Msg: string; Mode: Char = 'U');
begin
  mm.EventMessage(Msg, module, Mode);
end;

procedure TOC1Process.AlarmPost;
var
  strAlarm: string;
begin
  if (strMode <> 'Idle') and (strCtrl = 'Alarm') then
  begin
    SLEEP(1000);
    strAlarm := mm.GetDigSetStrID(PM_ALARM_POST, module);

    if (strAlarm = 'None') then
      Exit;

    AlarmAction(strAlarm);
    mm.SetDigID(SIGNALBUZZER_O, 'Off', _TM);

    mm.SetDigID(PM_ALARM_POST, 'None', module);
  end;
end;

procedure TOC1Process.AlarmAction(const AAction: string);
// Alarm Action.
var
  i, CellNum: Integer;
begin
  if (AAction = 'Retry') then
  begin
    if mm.GetDigCurStrID(PM_STS, module) = 'ProcessIng' then
      mm.SetDigID(GLASS_STATUS, 'ProcessIng', module);

    if strMode = 'Process' then
    begin
      if mm.GetDigSetStrID(DATALOGSET, module) = 'Disable' then
        mm.SetDigID(DATALOGSET, 'Enable', module);
    end;

    Step.Flag := True;
    Step.Times := 1;
    Step.dtCurTime := NOW;
    mm.SetDigID(PM_CTRL, 'Running', module);
  end
  else if (AAction = 'Ignore') then
  begin
    Step.Flag := True;
    Step.Times := 1;
    Step.dtCurTime := NOW;
    Inc(Step.Layer);
    mm.SetDigID(PM_CTRL, 'Running', module);

    if strMode = 'Process' then
    begin
      if mm.GetDigSetStrID(DATALOGSET, module) = 'Disable' then
        mm.SetDigID(DATALOGSET, 'Enable', module);
    end;

  end
  else if (AAction = 'Abort') then
  begin
    if strMode = 'Process' then
    begin
      mm.SetDigID(ROBOT_USED, 'NotUse', module);
      mm.SetDigID(DATALOGSET, 'Disable', module);
      for i := 1 to MaxCoDep do
      begin
        mm.SetAnaID(nArr_USEDCELL[i], 0, module);
      end;
    end;

    ActionList;
    SLEEP(1000);

    mm.SetDigID(PM_MODE, 'Idle', module);
    mm.SetDigID(PM_CTRL, 'Idle', module);
    mm.SetDigID(PM_STS, 'AbortOK', module);

    // if mm.GetDigSetStrID(MOVE_CTRL, module) <> 'Idle' then mm.SetDigID(MOVE_CTRL , 'Abort' , Module);

    EventLog('[' + ModuleName + '] Auto function is aborted.');

    if mm.IngCheck(mm.GetDigCurStrID(MANUALMOVE_STS, _TM)) then
    begin
      if (mm.GetDigCurStrID(MANUALMOVE_SOURCE, _TM) = 'OC1') or
        (mm.GetDigCurStrID(MANUALMOVE_TARGET, _TM) = 'OC1') then
      begin
        mm.SetDigID(MANUALMOVE_CTRL, 'Abort', _TM);
      end;
    end;

    if (mm.GetDigCurStrID(FULLAUTO_STS, _TM) = 'FullAutoIng') then
    begin
      // Scheduler.AlarmAction('Abort');
    end;
  end;
end;

procedure TOC1Process.ActionList; // Alarm Action List.
var
  i, CellNum, Depo1, Depo2, Depo3, Depo4: Integer;

begin
  if strMode = 'Vacuum' then
  begin
    mm.SetDigID(BASE_CTRL, 'Abort', module);
  end
  else if strMode = 'Vent' then
  begin
    mm.SetDigID(BASE_CTRL, 'Abort', module);
  end
  else if strMode = 'Ror' then
  begin
    mm.SetDigID(BASE_CTRL, 'Abort', module);
  end
  else if strMode = 'Regen' then
  begin
    mm.SetDigID(BASE_CTRL, 'Abort', module);
  end
  else if strMode = 'Process' then
  begin

    Depo1 := Round(Pb.UsedCell[1, Pb.StepNum]);
    Depo2 := Round(Pb.UsedCell[2, Pb.StepNum]);
    Depo3 := Round(Pb.UsedCell[3, Pb.StepNum]);
    Depo4 := Round(Pb.UsedCell[4,pb.StepNum]);
    {
      for i := 1 to MaxCell do
      begin
      if (mm.GetDigSetStrID(nArr_C_HUNTING_FLG[i], module) <> 'False') then
      mm.SetDigID(nArr_C_HUNTING_FLG[i], 'False', module);
      end;
    }
    mm.SetDigID(GLASS_STATUS, 'ProcessFail', module);
    mm.SetDigID(MAINSHUTTER_O, 'Close', module);
    F_ALL_CELL_SHUTTER('Close');

    if mm.GetDigSetStrID(DATALOGSET, module) <> 'Disable' then
      mm.SetDigID(DATALOGSET, 'Disable', module);

    // Thickness
    for i := 1 to MaxCoDep do
    begin
      CellNum := Round(Pb.UsedCell[1, Pb.StepNum]);
      if (Step.Layer = 13) and (i = 1) and (CellNum > 0) then
        FinalThickness := FinalThickness + (mm.GetAnaCurID(CURTHICKNESS, module)) -
          DepoStartThickness;
    end;

    // Cygnus
    for i := 1 to MaxCoDep do
    begin
      CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);
      mm.SetDigID(nArr_OC1_CH_CONT[CellNum], 'Stop', module);

    end;

    for i := 1 to MaxCoDep do
    begin
      CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);
      case CellNum of
        1 .. MaxCell:
          begin
            mm.SetDigID(nArr_C_TEMPRATE_O[CellNum], 'Temp', module);

            if mm.IngCheck(mm.GetDigSetStrID(nArr_C_RAMP_STS[CellNum], module)) then
            begin
              mm.SetDigID(nArr_C_RAMP_CTRL[CellNum], 'Abort', module);
            end;

            mm.SetDigID(nArr_C_CTRL[CellNum], 'Abort', module);

            if (Pb.CellStandbyTemp[i, Pb.StepNum] <= mm.GetAnaCurID(nArr_C_TEMP[CellNum], module))
            then
            begin
              mm.SetAnaID(nArr_C_TEMP[CellNum], Pb.CellStandbyTemp[i, Pb.StepNum], module);
            end
            else
            begin
              mm.SetAnaID(nArr_C_TEMP[CellNum], 0 , module);
              Sleep(500);
              mm.SetDigID(nArr_C_CONT[CellNum], 'Off', module);
            end;
          end; // end of 1..8
      end; // end of case(CellNum)
    end; // end of for(MaxCoDep)

    if (Step.Layer >= 10) and (Step.Layer <= 13) then
      Step.Layer := 10;
    // Alinger Rotation ~ Thickness Check

    // mm.SetDigID(MOVE_MODE, 'RoStop', module);
    // mm.SetDigID(MOVE_CTRL, 'Run', module);
    // mm.SetDigID(MOVE_STS , 'Idle', module);

    if mm.GetDigCurStrID(ALIGNER_STS, module) = 'Rotation' then
    begin
      mm.SetDigID(MOVE_MODE, 'RoStop', module);
      mm.SetDigID(MOVE_CTRL, 'Run', module);
      mm.SetDigID(MOVE_STS, 'Idle', module);
    end
    else
    begin
      mm.SetDigID(MOVE_CTRL, 'Abort', module);
    end;
  end; // end of if (process)
end;

procedure TOC1Process.ShowAlarm(Id: Integer); // Alarm.
begin
  mm.SetDigID(PM_ALARM_POST, 'None', module);
  mm.alarm_post(Id, module); // Alarm Post.

  ActionList; // Alarm Action.
  mm.SetDigID(PM_CTRL, 'Alarm', module);

  mm.SetDigID(SIGNALBUZZER_O, 'On', _TM); // Buzzer On.
end;

// ==============================================================================
// Vacuum Start.
// ==============================================================================

procedure TOC1Process.VacuumProgress;
begin
  if (strMode = 'Vacuum') and (strCtrl = 'Run') then
  begin
    Step.Flag := True;
    Step.Layer := 1;
    Step.Times := 1;
    Step.dtCurTime := NOW;

    mm.SetDigID(DRYPUMP_USED, 'Waiting', module);

    mm.SetDigID(PM_CTRL, 'Running', module);
    mm.SetDigID(PM_STS, 'VacuumIng', module);

    // EventLog('[' + ModuleName + '] AUTO VACUUM START.');
  end
  else if (strMode = 'Vacuum') and (strCtrl = 'Running') then
  begin
    case (Step.Layer) of
      1:
        P_VAC_Check;
      2:
        P_VAC_End;
    end;
  end;
end;

// Layer 1
procedure TOC1Process.P_VAC_Check;
begin
  if (Step.Flag) then
  begin
    mm.SetDigID(BASE_MODE, 'Vacuum', module);
    mm.SetDigID(BASE_CTRL, 'Run', module);
    mm.SetDigID(BASE_STS, 'Idle', module);
    SLEEP(1000);

    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigSetStrID(BASE_STS, module) = 'VacuumOK') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

procedure TOC1Process.P_VAC_End;
begin
  mm.SetDigID(DRYPUMP_USED, 'NotUse', module);

  mm.SetDigID(PM_MODE, 'Idle', module);
  mm.SetDigID(PM_CTRL, 'Idle', module);
  mm.SetDigID(PM_STS, 'VacuumOK', module);

  EventLog('[' + ModuleName + '] Auto Pumping END.');
end;

// ==============================================================================
// Vent Start.
// ==============================================================================

procedure TOC1Process.VentProgress;
begin
  if (strMode = 'Vent') and (strCtrl = 'Run') then
  begin
    Step.Flag := True;
    Step.Layer := 1;
    Step.Times := 1;
    Step.dtCurTime := NOW;

    mm.SetDigID(PM_CTRL, 'Running', module);
    mm.SetDigID(PM_STS, 'VentIng', module);

    // EventLog('[' + ModuleName + '] AUTO Vent START.');
  end
  else if (strMode = 'Vent') and (strCtrl = 'Running') then
  begin
    case (Step.Layer) of
      1:
        P_VENT_Check;
      2:
        P_VENT_End;
    end;
  end;
end;

// Layer 1
procedure TOC1Process.P_VENT_Check;
begin
  if (Step.Flag) then
  begin
    mm.SetDigID(BASE_MODE, 'Vent', module);
    mm.SetDigID(BASE_CTRL, 'Run', module);
    mm.SetDigID(BASE_STS, 'Idle', module);
    SLEEP(1000);

    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigSetStrID(BASE_STS, module) = 'VentOK') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

procedure TOC1Process.P_VENT_End;
begin
  mm.SetDigID(PM_MODE, 'Idle', module);
  mm.SetDigID(PM_CTRL, 'Idle', module);
  mm.SetDigID(PM_STS, 'VentOK', module);

  EventLog('[' + ModuleName + '] Auto Vent END.');
end;

// ==============================================================================
// Ror Start.
// ==============================================================================

procedure TOC1Process.RorProgress;
begin
  if (strMode = 'Ror') and (strCtrl = 'Run') then
  begin
    Step.Flag := True;
    Step.Layer := 1;
    Step.Times := 1;
    Step.dtCurTime := NOW;

    ZeroMemory(@Ror, SizeOf(Ror));

    mm.SetDigID(PM_CTRL, 'Running', module);
    mm.SetDigID(PM_STS, 'RorIng', module);

    // EventLog('[' + ModuleName + '] AUTO Ror START.');
  end
  else if (strMode = 'Ror') and (strCtrl = 'Running') then
  begin
    case (Step.Layer) of
      1:
        P_ROR_Check;
      2:
        P_ROR_End;
    end;
  end;
end;

// Layer 1
procedure TOC1Process.P_ROR_Check;
begin
  if (Step.Flag) then
  begin
    mm.SetDigID(BASE_MODE, 'Ror', module);
    mm.SetDigID(BASE_CTRL, 'Run', module);
    mm.SetDigID(BASE_STS, 'Idle', module);
    SLEEP(1000);

    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigSetStrID(BASE_STS, module) = 'RorOK') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

procedure TOC1Process.P_ROR_End;
begin
  mm.SetDigID(PM_MODE, 'Idle', module);
  mm.SetDigID(PM_CTRL, 'Idle', module);
  mm.SetDigID(PM_STS, 'RorOK', module);

  EventLog('[' + ModuleName + '] Auto ROR END.');
end;

// ==============================================================================
// Regen Start.
// ==============================================================================

procedure TOC1Process.RegenProgress;
begin
  if (strMode = 'Regen') and (strCtrl = 'Run') then
  begin
    Step.Flag := True;
    Step.Layer := 1;
    Step.Times := 1;
    Step.dtCurTime := NOW;

    mm.SetDigID(PM_CTRL, 'Running', module);
    mm.SetDigID(PM_STS, 'RegenIng', module);

    Regen.Count := 1;

    mm.SetDigID(DRYPUMP_USED, 'Waiting', module);
    // EventLog('[' + ModuleName + '] AUTO Regen START.');
  end
  else if (strMode = 'Regen') and (strCtrl = 'Running') then
  begin
    case (Step.Layer) of
      1:
        P_REGEN_Check;
      2:
        P_REGEN_End;
    end;
  end;
end;

// Layer 1
procedure TOC1Process.P_REGEN_Check;
begin
  if (Step.Flag) then
  begin
    mm.SetDigID(BASE_MODE, 'Regen', module);
    mm.SetDigID(BASE_CTRL, 'Run', module);
    mm.SetDigID(BASE_STS, 'Idle', module);
    SLEEP(1000);

    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigSetStrID(BASE_STS, module) = 'RegenOK') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

procedure TOC1Process.P_REGEN_End;
begin
  mm.SetDigID(PM_MODE, 'Idle', module);
  mm.SetDigID(PM_CTRL, 'Idle', module);
  mm.SetDigID(PM_STS, 'RegenOK', module);

  EventLog(ModuleName + ' Auto Regen END.');

  if mm.GetDigSetStrID(REGEN_AFTER_VACUUM, module) = 'True' then
  begin
    mm.SetDigID(PM_MODE, 'Vacuum', module);
    mm.SetDigID(PM_CTRL, 'Run', module);
  end;
end;

// ==============================================================================
// Process Start.
// ==============================================================================

procedure TOC1Process.ProcessProgress;
var
  i: Integer;
begin
  if (strMode = 'Process') and (strCtrl = 'Run') then
  begin
    if ((mm.GetDigSetStrID(FULLAUTO_STS, _TM) = 'FullAutoIng') and
      (mm.GetDigSetStrID(CYCLETEST_FLG, _TM) = 'True')) then
    begin
      Step.Flag := True;
      Step.Layer := 101;
      // Step.Layer := 1;
      Step.Times := 1;
      Step.dtCurTime := NOW;
    end
    else
    begin
      Step.Flag := True;
      Step.Layer := 1;
      Step.Times := 1;
      Step.dtCurTime := NOW;
    end;

    // channel false : add (ksy) 2014. 11. 10
    // request processteam delete nArr_C_HUNTING_FLG;
    {
      for i := 1 to MaxCell do
      begin
      if (mm.GetDigSetStrID(nArr_C_HUNTING_FLG[i], module) <> 'False') then
      mm.SetDigID(nArr_C_HUNTING_FLG[i], 'False', module);
      end;
    }

    mm.SetDigID(PM_CTRL, 'Running', module);
    mm.SetDigID(PM_STS, 'ProcessIng', module);

    Check.MainRateCount := 0;

    if (mm.GetDigSetStrID(DATALOGSET, module) <> 'Logging') then
      mm.SetDigID(DATALOGSET, 'Enable', module);

    SLEEP(1500); // 2015.04.03 add

    mm.SetDigID(GLASS_STATUS, 'ProcessIng', module);

    for i := 1 to MaxCoDep do
    begin
      mm.SetAnaID(nArr_USEDCELL[i], 0, module);
    end;

    ProcessStartTime := 0;
    ProcessStartTime := NOW;

    EventLog('[' + ModuleName + ']' + ' Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
      ' Auto Process START.');
  end
  else if (strMode = 'Process') and (strCtrl = 'Running') then
  begin
    case (Step.Layer) of
      STEP_P_PROCESS_RecipeLoading:
        P_PROCESS_RecipeLoading(mm.GetStrSetMsgID(RECNAME, module));
      STEP_P_PROCESS_DoorCloseCheck:
        P_PROCESS_DoorCloseCheck;
      STEP_P_PROCESS_GateValveCloseCheck:
        P_PROCESS_GateValveCloseCheck;
      STEP_P_PROCESS_VacuumCheck:
        P_PROCESS_VacuumCheck;
      STEP_P_PROCESS_GlassCheck:
        P_PROCESS_GlassCheck;
      STEP_P_PROCESS_MainShutterClose:
        P_PROCESS_MainShutterClose;
      STEP_P_PROCESS_MaskChangePick:
        P_PROCESS_MaskChangePick;
      STEP_P_PROCESS_MaskChangePlace:
        P_PROCESS_MaskChangePlace;
      STEP_P_PROCESS_Align:
        P_PROCESS_Align;
      STEP_P_PROCESS_AlignerRotation:
        P_PROCESS_AlignerRotation;
      STEP_P_PROCESS_CellProcessCheck:
        P_PROCESS_CellProcessCheck;

      STEP_P_PROCESS_MainShutterOpen:
        P_PROCESS_MainShutterOpen;
      STEP_P_PROCESS_ThicknessCheck:
        P_PROCESS_ThicknessCheck;
      STEP_P_PROCESS_MainShutterCloseCheck:
        P_PROCESS_MainShutterCloseCheck;
      STEP_P_PROCESS_CellAfterCheck:
        P_PROCESS_CellAfterCheck;
      STEP_P_PROCESS_CellWaitTimeCheck:
        P_PROCESS_CellWaitTimeCheck;
      STEP_P_PROCESS_EndStepCheck:
        P_PROCESS_EndStepCheck;
      STEP_P_PROCESS_AlignerGlassLoad:
        P_PROCESS_AlignerGlassLoad;
      STEP_P_PROCESS_ProcessEnd:
        P_PROCESS_ProcessEnd;

      30:
        P_PROCESS_RateCheck; // For rate hunting check...

      // Cycle Test
      101:
        P_PROCESS_RecipeLoading(mm.GetStrSetMsgID(RECNAME, module));
      102:
        P_PROCESS_DoorCloseCheck;
      103:
        P_PROCESS_GateValveCloseCheck;
      104:
        P_PROCESS_VacuumCheck;
      105:
        P_PROCESS_GlassCheck;
      106:
        P_PROCESS_MainShutterClose;
      107:
        P_PROCESS_Align;
      108:
        P_PROCESS_AlignerRotation;
      109:
        begin
          SLEEP(30000);
          mm.SetDigID(MOVE_MODE, 'RoStop', module);
          mm.SetDigID(MOVE_CTRL, 'Run', module);
          mm.SetDigID(MOVE_STS, 'Idle', module);

          Inc(Step.Layer);
        end;
      110:
        P_PROCESS_AlignerGlassLoad;
      111:
        P_PROCESS_ProcessEnd;
    end;
  end;
end;

// Layer 1 : Recipe Loading
procedure TOC1Process.P_PROCESS_RecipeLoading(Path: string);
var
  F: TFileStream;
  i: Integer;
begin
  if (Step.Flag) then
  begin
    if FileExists(Path) then
    begin
      F := TFileStream.Create(Path, fmOpenRead);
      F.Read(Recipedata, SizeOf(Recipedata));
      F.Free;

      ZeroMemory(@Pb, SizeOf(Pb));

      Pb.TotalTime := 0;
      Pb.TotalStep := Recipedata.total_step;

      for i := 0 to Recipedata.total_step do
      begin
        Pb.StepName[i + 1] := Recipedata.StepName[i];

        // Recipe List Start.
        Pb.MaskChangeID[i + 1]          := Recipedata.recdata[i][0];
        Pb.AlignUse[i + 1]              := Recipedata.recdata[i][1];
        Pb.AlignXShift[i + 1]           := Recipedata.recdata[i][2];
        Pb.AlignYShift[i + 1]           := Recipedata.recdata[i][3];
        Pb.RateStableTime[i + 1]        := Recipedata.recdata[i][4];

        Pb.UsedCell[1, i + 1]           := Recipedata.recdata[i][5];
        Pb.SensorNo[1, i + 1]           := Recipedata.recdata[i][6];
        Pb.CellRate[1, i + 1]           := Recipedata.recdata[i][7];
        Pb.TargetThickness[i + 1]       := Recipedata.recdata[i][8];
        Pb.CellProgramNum[1, i + 1]     := Recipedata.recdataStr[i][9];
        Pb.CellStandbyTemp[1, i + 1]    := Recipedata.recdata[i][10];
        Pb.CellBotStandbyTemp[1, i + 1] := Recipedata.recdata[i][11];
        Pb.RampingNum[1, i + 1]         := Recipedata.recdataStr[i][12];
        Pb.BotRampingNum[1, i + 1]      := Recipedata.recdataStr[i][13];
        Pb.AfterProcess[1, i + 1]       := Recipedata.recdata[i][14];
        Pb.DelayTime[1, i + 1]          := Recipedata.recdata[i][15];

        Pb.UsedCell[2, i + 1]           := Recipedata.recdata[i][16];
        Pb.SensorNo[2, i + 1]           := Recipedata.recdata[i][17];
        Pb.CellRate[2, i + 1]           := Recipedata.recdata[i][18];
        Pb.CellProgramNum[2, i + 1]     := Recipedata.recdataStr[i][19];
        Pb.CellStandbyTemp[2, i + 1]    := Recipedata.recdata[i][20];
        Pb.CellBotStandbyTemp[2, i + 1] := Recipedata.recdata[i][21];
        Pb.RampingNum[2, i + 1]         := Recipedata.recdataStr[i][22];
        Pb.BotRampingNum[2, i + 1]      := Recipedata.recdataStr[i][23];
        Pb.AfterProcess[2, i + 1]       := Recipedata.recdata[i][24];
        Pb.DelayTime[2, i + 1]          := Recipedata.recdata[i][25];

        Pb.UsedCell[3, i + 1]           := Recipedata.recdata[i][26];
        Pb.SensorNo[3, i + 1]           := Recipedata.recdata[i][27];
        Pb.CellRate[3, i + 1]           := Recipedata.recdata[i][28];
        Pb.CellProgramNum[3, i + 1]     := Recipedata.recdataStr[i][29];
        Pb.CellStandbyTemp[3, i + 1]    := Recipedata.recdata[i][30];
        Pb.CellBotStandbyTemp[3, i + 1] := Recipedata.recdata[i][31];
        Pb.RampingNum[3, i + 1]         := Recipedata.recdataStr[i][32];
        Pb.BotRampingNum[3, i + 1]      := Recipedata.recdataStr[i][33];
        Pb.AfterProcess[3, i + 1]       := Recipedata.recdata[i][34];
        Pb.DelayTime[3, i + 1]          := Recipedata.recdata[i][35];

        Pb.UsedCell[4, i + 1]           := Recipedata.recdata[i][36];
        Pb.SensorNo[4, i + 1]           := Recipedata.recdata[i][37];
        Pb.CellRate[4, i + 1]           := Recipedata.recdata[i][38];
        Pb.CellProgramNum[4, i + 1]     := Recipedata.recdataStr[i][39];
        Pb.CellStandbyTemp[4, i + 1]    := Recipedata.recdata[i][40];
        Pb.CellBotStandbyTemp[4, i + 1] := Recipedata.recdata[i][41];
        Pb.RampingNum[4, i + 1]         := Recipedata.recdataStr[i][42];
        Pb.BotRampingNum[4, i + 1]      := Recipedata.recdataStr[i][43];
        Pb.AfterProcess[4, i + 1]       := Recipedata.recdata[i][44];
        Pb.DelayTime[4, i + 1]          := Recipedata.recdata[i][45];
      end;

      Pb.StepNum := 1;

      mm.SetDigID(RECTOTALSTEP, IntToStr(Pb.TotalStep), module);
      mm.SetDigID(RECCURSTEP, IntToStr(Pb.StepNum), module);

      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      ShowAlarm(ALM_PROCESS_RECIPE);
      // Recipe Name is not exist,Check the Recipe
    end;
  end;
end;

//

// Layer 2 : Door Close Check
procedure TOC1Process.P_PROCESS_DoorCloseCheck;
begin
  if (Step.Flag) then
  begin
    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigCurStrID(DOOR_SN_I, module) = 'Close') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      ShowAlarm(ALM_VACUUM_DOOR); // Door is Opened. Check!
    end;
  end;
end;

// Layer 3 : VAC_Gate Valve Close Check
procedure TOC1Process.P_PROCESS_GateValveCloseCheck;
begin
  if (Step.Flag) then
  begin
    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigCurStrID(TM_OC1_GATE_VV_IO, _TM) = 'Close') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      ShowAlarm(ALM_PROCESS_GATE);
      // TM/OC1 Gate Valve is not Please Closed. Check!
    end;
  end;
end;

// Layer 4 : Vacuum Check
procedure TOC1Process.P_PROCESS_VacuumCheck;
begin
  if (Step.Flag) then
  begin
    EventLog('Checking the [' + ModuleName + '] chamber base pressure: ' + mm.GetAnaCurStrID(ION_GAUGE_I, module) +
      ' <= ' + mm.GetAnaSetStrID(BASEPRESSURE, module) + ' Torr.');

    Step.Flag  := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end else
  begin
    if (mm.GetAnaCurID(ION_GAUGE_I, module) <= mm.GetAnaSetID(BASEPRESSURE, module)) then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end else
    begin
      if (mm.GetAnaSetID(BASEPUMPINGTIMEOUT, module) > 0) and
         (Step.Times >= mm.GetAnaSetID(BASEPUMPINGTIMEOUT, module)) then
        ShowAlarm(ALM_Process_Vacuum); //Process Vacuum is High,Check the HiVac or Full Gauge
      INC_TIMES;
    end;
  end;
end;

// Layer 5 : Glass Check
procedure TOC1Process.P_PROCESS_GlassCheck;
var
  i: byte;
begin
  if (Step.Flag) then
  begin

    // SENSOR SWITCHING.
//    P_PROCESS_SN_SWITCHING;
    // Cell Recipe Loading.
    F_CellRecipe;

    EventLog('[' + ModuleName + ']' + ' Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
      ' exist check.');

    mm.SetAnaID(TRGTHICKNESS, Round(Pb.TargetThickness[Pb.StepNum]), module);
    mm.SetAnaID(CURTHICKNESS, 0, module);
    FinalThickness := 0;

    for i := 1 to MaxCoDep do
    begin
      mm.SetAnaID(nArr_USEDCELL[i], Pb.UsedCell[i, Pb.StepNum], module);
    end;

    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigSetStrID(GLASS_IN_STS, module) = 'In') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      ShowAlarm(ALM_PROCESS_GLASS_DETECT);
    end;
  end;
end;

// Layer 6 : Mainshutter Close
procedure TOC1Process.P_PROCESS_MainShutterClose;
begin
  if (Step.Flag) then
  begin
    EventLog('[' + ModuleName + '] MainShutter Close Check!');

    F_ALL_PROCESS_CELL_SHUTTER('Close');

    mm.SetAnaID(CURTHICKNESS, 0, module);

    if (mm.GetDigCurStrID(MAINSHUTTER_I, module) <> 'Close') then
      mm.SetDigID(MAINSHUTTER_O, 'Close', module);

    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigCurStrID(MAINSHUTTER_I, module) = 'Close') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      if (Step.Times >= mm.GetAnaSetID(VALVEOPENCLOSETIMEOUT, module)) then
        ShowAlarm(ALM_PROCESS_SHUTTER_CLOSE);
      // Main Shutter is not been closed
      INC_TIMES;
    end;
  end;
end;

// Layer 7 : Mask Change Pick
procedure TOC1Process.P_PROCESS_MaskChangePick;
var
  i, CurrMaskID: Integer;
begin
  if (Step.Flag) then
  begin
    if (Pb.MaskChangeID[Pb.StepNum] = 0) then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else if (mm.GetDigCurStrID(MASK_IN_STS, module) <> 'In') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      if (Pb.MaskChangeID[Pb.StepNum] = mm.GetAnaSetID(MASK_ID, module)) then
      begin
        Step.Flag := True;
        Inc(Step.Layer);
      end
      else
      begin
        // Moving Check...
        if (mm.GetDigCurStrID(MANUALMOVE_MODE, _TM) <> 'Idle') or
          (mm.GetDigCurStrID(MANUALMOVE_CTRL, _TM) <> 'Idle') then
        begin
          if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
          begin
            mm.SetDigID(ROBOT_USED, 'NotUse', module);
          end;
          Exit;
        end;

        // 2013.01.15 hdkim add  : Fullauto Hold 시 Mask change 불가
        if (mm.GetDigCurStrID(FULLAUTO_MODE, _TM) = 'FullAuto') and
          (mm.GetDigCurStrID(FULLAUTO_CTRL, _TM) = 'Hold') then
        begin
          if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
          begin
            mm.SetDigID(ROBOT_USED, 'NotUse', module);
          end;
          Exit;
        end;

        if (mm.GetDigCurStrID(GLASS_IN_STS, _TM) = 'In') then
        begin
          if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
          begin
            mm.SetDigID(ROBOT_USED, 'NotUse', module);
          end;
          ShowAlarm(ALM_PROCESS_TM_GLASS_EXIST);
          Exit;
        end
        else if (mm.GetDigCurStrID(MASK_IN_STS, _TM) = 'In') then
        begin
          if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
          begin
            mm.SetDigID(ROBOT_USED, 'NotUse', module);
          end;
          ShowAlarm(ALM_PROCESS_TM_MASK_EXIST);
          Exit;
        end;

        CurrMaskID := Round(mm.GetAnaSetID(MASK_ID, module));

        if (CurrMaskID >= 1) and (CurrMaskID <= MASK_MAX_CNT) then
        begin
          if (mm.GetDigCurStrID(PM_MODE, _LL) <> 'Idle') and
            (mm.GetDigCurStrID(PM_CTRL, _LL) <> 'Idle') and
            (mm.GetDigCurStrID(MAP_MODE, _LL) <> 'Idle') and
            (mm.GetDigCurStrID(MAP_CTRL, _LL) <> 'Idle') then
          begin
            if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
            begin
              mm.SetDigID(ROBOT_USED, 'NotUse', module);
            end;
            Exit;
          end;

          // Cassette Slot Empty Check.
          for i := 1 to MASK_MAX_CNT do
          begin
            if Round(mm.GetAnaSetID(MASK_ID, module)) = i then
            begin
              if mm.GetDigCurStrID(nArr_MASK__IN_STS[i], _LL) = 'None' then
              begin
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
                begin
                  mm.SetDigID(ROBOT_USED, 'Waiting', module);
                end;
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'Permission' then
                begin
                  mm.SetDigID(CASSETTE_SLOT_SET, 'Mask' + IntToStr(i), _LL);

                  mm.SetDigID(MANUALMOVE_SOURCE, 'OC1', _TM);
                  mm.SetDigID(MANUALMOVE_TARGET, 'LL', _TM);
                  mm.SetDigID(MANUALMOVE_GLSSMSK, 'Mask', _TM);
                end
                else
                begin
                  Exit;
                end;
              end
              else
              begin
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
                begin
                  mm.SetDigID(ROBOT_USED, 'NotUse', module);
                end;
                ShowAlarm(ALM_PROCESS_LL_MASK_EXIST);
                // The mask in LL exists.
                Exit;
              end;
            end;
          end;

        end;

        mm.SetDigID(MANUALMOVE_MODE, 'Move', _TM);
        mm.SetDigID(MANUALMOVE_CTRL, 'Run', _TM);
        mm.SetDigID(MANUALMOVE_STS, 'Idle', _TM);
        SLEEP(500);

        Step.Flag := False;
        Step.Times := 1;
        Step.dtCurTime := NOW;
      end;
    end;
  end
  else
  begin
    if mm.GetDigCurStrID(MANUALMOVE_STS, _TM) = 'MoveOK' then
    begin
      mm.SetDigID(ROBOT_USED, 'NotUse', module);
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

// Layer 8 : Mask Change Place
procedure TOC1Process.P_PROCESS_MaskChangePlace;
var
  CurrMaskID: Integer;
  i: Integer;
  SetCheck: Boolean;
begin
  if (Step.Flag) then
  begin
    if Pb.MaskChangeID[Pb.StepNum] = 0 then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else if (mm.GetDigCurStrID(MASK_IN_STS, module) = 'In') then
    begin
      if (Pb.MaskChangeID[Pb.StepNum] = mm.GetAnaSetID(MASK_ID, module)) then
      begin
        Step.Flag := True;
        Inc(Step.Layer);
      end
      else
      begin
        Step.Flag := True;
        Dec(Step.Layer);
      end;
    end
    else
    begin
      // Moving Check...
      if (mm.GetDigSetStrID(MANUALMOVE_MODE, _TM) <> 'Idle') or
        (mm.GetDigSetStrID(MANUALMOVE_CTRL, _TM) <> 'Idle') then
      begin
        if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
        begin
          mm.SetDigID(ROBOT_USED, 'NotUse', module);
        end;
        Exit;
      end;

      if (mm.GetDigSetStrID(GLASS_IN_STS, _TM) = 'In') then
      begin
        if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
        begin
          mm.SetDigID(ROBOT_USED, 'NotUse', module);
        end;
        ShowAlarm(ALM_PROCESS_TM_GLASS_EXIST);
        Exit;
      end
      else if (mm.GetDigSetStrID(MASK_IN_STS, _TM) = 'In') then
      begin
        if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
        begin
          mm.SetDigID(ROBOT_USED, 'NotUse', module);
        end;
        ShowAlarm(ALM_PROCESS_TM_MASK_EXIST);
        Exit;
      end;

      CurrMaskID := Round(Pb.MaskChangeID[Pb.StepNum]);

      if ((CurrMaskID >= 1) and (CurrMaskID <= MASK_MAX_CNT)) then
      begin
        SetCheck := False;

        for i := 1 to MASK_MAX_CNT do
        begin
          if CurrMaskID = i then
          begin
            if mm.GetDigSetStrID(nArr_MASK__IN_STS[i], _LL) = 'In' then
            begin
              if (mm.GetDigCurStrID(PM_MODE, _LL) = 'Idle') and
                (mm.GetDigCurStrID(PM_CTRL, _LL) = 'Idle') and
                (mm.GetDigCurStrID(MAP_MODE, _LL) = 'Idle') and
                (mm.GetDigCurStrID(MAP_CTRL, _LL) = 'Idle') then
              begin
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
                begin
                  mm.SetDigID(ROBOT_USED, 'Waiting', module);
                end;
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'Permission' then
                begin
                  mm.SetDigID(CASSETTE_SLOT_SET, 'Mask' + IntToStr(i), _LL);

                  mm.SetDigID(MANUALMOVE_SOURCE, 'LL', _TM);
                  mm.SetDigID(MANUALMOVE_TARGET, 'OC1', _TM);
                  mm.SetDigID(MANUALMOVE_GLSSMSK, 'Mask', _TM);
                  SetCheck := True;
                  break;
                end
                else
                begin
                  Exit;
                end;
              end
              else
              begin
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
                begin
                  mm.SetDigID(ROBOT_USED, 'NotUse', module);
                end;
                ShowAlarm(ALM_PROCESS_MASK_CHANGE_PLACE);
                // LL Cassette SemiAuto Running...
                Exit;
              end;
            end;
          end;
        end;
      end
      else
      begin
        if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
        begin
          mm.SetDigID(ROBOT_USED, 'NotUse', module);
        end;
        ShowAlarm(ALM_PROCESS_LL_MASK_NOTEXIST);
        // Mask ID is not found.
        Exit;
      end;

      // Check other chamber
      if SetCheck <> True then
      begin
        // Mask MC -> OC1
        if (mm.GetDigCurStrID(MASK_IN_STS, _MC) = 'In') and
          (Round(mm.GetAnaSetID(MASK_ID, _MC)) = CurrMaskID) then
        begin
          if ((mm.GetDigCurStrID(PM_MODE, _MC) = 'Idle') and
            (mm.GetDigCurStrID(PM_CTRL, _MC) = 'Idle')) and
            ((mm.GetDigCurStrID(MOVE_MODE, _MC) = 'Idle') and
            (mm.GetDigCurStrID(MOVE_CTRL, _MC) = 'Idle')) then
          begin
            if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
            begin
              mm.SetDigID(ROBOT_USED, 'Waiting', module);
            end;
            if mm.GetDigSetStrID(ROBOT_USED, module) = 'Permission' then
            begin
              mm.SetDigID(MANUALMOVE_SOURCE, 'MC', _TM);
              mm.SetDigID(MANUALMOVE_TARGET, 'OC1', _TM);
              mm.SetDigID(MANUALMOVE_GLSSMSK, 'Mask', _TM);

              SetCheck := True;
            end
            else
            begin
              Exit;
            end;
          end
          else
          begin
            if mm.GetDigSetStrID(ROBOT_USED, module) <> 'NotUse' then
            begin
              mm.SetDigID(ROBOT_USED, 'NotUse', module);
            end;
            Exit;
          end;
        end else
                // Mask OC4 -> OC1
        if (mm.GetDigCurStrID(MASK_IN_STS, _OC4) = 'In')                 and
           (Round(mm.GetAnaSetID(MASK_ID, _OC4)) = CurrMaskID) then
        begin
          if ((mm.GetDigCurStrID(PM_MODE,    _OC4) = 'Idle')  and
              (mm.GetDigCurStrID(PM_CTRL,    _OC4) = 'Idle')) and
             ((mm.GetDigCurStrID(MOVE_MODE, _OC4) = 'Idle')  and
              (mm.GetDigCurStrID(MOVE_CTRL, _OC4) = 'Idle')) then
          begin
            if mm.GetDigSetStrID(ROBOT_USED, module) =  'NotUse' then
            begin
              mm.SetDigID(ROBOT_USED, 'Waiting', module);
            end;
            if mm.GetDigSetStrID(ROBOT_USED, module) =  'Permission' then
            begin
              mm.SetDigID(MANUALMOVE_SOURCE,  'OC4',  _TM);
              mm.SetDigID(MANUALMOVE_TARGET,  'OC1',  _TM);
              mm.SetDigID(MANUALMOVE_GLSSMSK, 'Mask', _TM);

              SetCheck := True;
            end else
            begin
              Exit;
            end;
          end else
          begin
            if mm.GetDigSetStrID(ROBOT_USED, module)  <>  'NotUse' then
            begin
              mm.SetDigID(ROBOT_USED, 'NotUse', module);
            end;
            Exit;
          end;
        end else
          // Mask OC3 -> OC1
          if (mm.GetDigCurStrID(MASK_IN_STS, _OC3) = 'In') and
            (Round(mm.GetAnaSetID(MASK_ID, _OC3)) = CurrMaskID) then
          begin
            if ((mm.GetDigCurStrID(PM_MODE, _OC3) = 'Idle') and
              (mm.GetDigCurStrID(PM_CTRL, _OC3) = 'Idle')) and
              ((mm.GetDigCurStrID(MOVE_MODE, _OC3) = 'Idle') and
              (mm.GetDigCurStrID(MOVE_CTRL, _OC3) = 'Idle')) then
            begin
              if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
              begin
                mm.SetDigID(ROBOT_USED, 'Waiting', module);
              end;
              if mm.GetDigSetStrID(ROBOT_USED, module) = 'Permission' then
              begin
                mm.SetDigID(MANUALMOVE_SOURCE, 'OC3', _TM);
                mm.SetDigID(MANUALMOVE_TARGET, 'OC1', _TM);
                mm.SetDigID(MANUALMOVE_GLSSMSK, 'Mask', _TM);

                SetCheck := True;
              end
              else
              begin
                Exit;
              end;
            end
            else
            begin
              if mm.GetDigSetStrID(ROBOT_USED, module) <> 'NotUse' then
              begin
                mm.SetDigID(ROBOT_USED, 'NotUse', module);
              end;
              Exit;
            end;
          end
          else
            // Mask OC2 -> OC1
            if (mm.GetDigCurStrID(MASK_IN_STS, _OC2) = 'In') and
              (Round(mm.GetAnaSetID(MASK_ID, _OC2)) = CurrMaskID) then
            begin
              if ((mm.GetDigCurStrID(PM_MODE, _OC2) = 'Idle') and
                (mm.GetDigCurStrID(PM_CTRL, _OC2) = 'Idle')) and
                ((mm.GetDigCurStrID(MOVE_MODE, _OC2) = 'Idle') and
                (mm.GetDigCurStrID(MOVE_CTRL, _OC2) = 'Idle')) then
              begin
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
                begin
                  mm.SetDigID(ROBOT_USED, 'Waiting', module);
                end;
                if mm.GetDigSetStrID(ROBOT_USED, module) = 'Permission' then
                begin
                  mm.SetDigID(MANUALMOVE_SOURCE, 'OC2', _TM);
                  mm.SetDigID(MANUALMOVE_TARGET, 'OC1', _TM);
                  mm.SetDigID(MANUALMOVE_GLSSMSK, 'Mask', _TM);

                  SetCheck := True;
                end
                else
                begin
                  Exit;
                end;
              end
              else
              begin
                if mm.GetDigSetStrID(ROBOT_USED, module) <> 'NotUse' then
                begin
                  mm.SetDigID(ROBOT_USED, 'NotUse', module);
                end;
                Exit;
              end;
            end
            else
            begin
              if mm.GetDigSetStrID(ROBOT_USED, module) = 'NotUse' then
              begin
                mm.SetDigID(ROBOT_USED, 'NotUse', module);
              end;
              ShowAlarm(ALM_PROCESS_LL_MASK_NOTEXIST);
              // The mask in LL does not exist.
              Exit;
            end;
      end;

      if SetCheck = True then
      begin
        mm.SetDigID(MANUALMOVE_MODE, 'Move', _TM);
        mm.SetDigID(MANUALMOVE_CTRL, 'Run', _TM);
        mm.SetDigID(MANUALMOVE_STS, 'Idle', _TM);
        SLEEP(500);

        Step.Flag := False;
        Step.Times := 1;
        Step.dtCurTime := NOW;
      end;
    end;

  end
  else
  begin
    if mm.GetDigCurStrID(MANUALMOVE_STS, _TM) = 'MoveOK' then
    begin
      mm.SetDigID(ROBOT_USED, 'NotUse', module);

      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

// Layer 9 : Aligner Rotation Start
procedure TOC1Process.P_PROCESS_AlignerRotation;
begin
  if (Step.Flag) then
  begin
    EventLog('[' + ModuleName + '] Aligner rotation check!');

    if (mm.GetDigSetStrID(MOVE_STS, module) = 'RotationOK') then
    begin
      EventLog('[' + ModuleName + '] Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
        ' Aligner rotating.');
      Step.Flag := True;
      Inc(Step.Layer);
      Exit;
    end
    else
    begin
      mm.SetDigID(MOVE_MODE, 'RoStart', module);
      mm.SetDigID(MOVE_CTRL, 'Run', module);
      mm.SetDigID(MOVE_STS, 'Idle', module);
      SLEEP(1000);

      Step.Flag := False;
      Step.Times := 1;
      Step.dtCurTime := NOW;
    end;
  end
  else
  begin
    if (mm.GetDigSetStrID(MOVE_STS, module) = 'RoStartOK') then
    begin
      EventLog('[' + ModuleName + '] Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
        ' Aligner rotation start.');

      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

// Layer 10 : Cell Process Start
procedure TOC1Process.P_PROCESS_CellProcessCheck;
var
  i: Integer;
begin
  if (Step.Flag) then
  begin
    for i := 1 to MaxCoDep do
    begin
      if (Pb.UsedCell[i, Pb.StepNum] <> 0) then
      begin
        mm.SetDigID(nArr_C_MODE[Round(Pb.UsedCell[i, Pb.StepNum])], 'Process', module);
        mm.SetDigID(nArr_C_CTRL[Round(Pb.UsedCell[i, Pb.StepNum])], 'Run', module);
        mm.SetDigID(nArr_C_STS[Round(Pb.UsedCell[i, Pb.StepNum])], 'Idle', module);
        SLEEP(1000);
      end;
    end;
    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if ((Pb.UsedCell[1, Pb.StepNum] = 0) or
      (mm.GetDigCurStrID(nArr_C_STS[Round(Pb.UsedCell[1, Pb.StepNum])], module) = 'ProcessOK')) and
      ((Pb.UsedCell[2, Pb.StepNum] = 0) or
      (mm.GetDigCurStrID(nArr_C_STS[Round(Pb.UsedCell[2, Pb.StepNum])], module) = 'ProcessOK')) and
      ((Pb.UsedCell[3, Pb.StepNum] = 0) or
      (mm.GetDigCurStrID(nArr_C_STS[Round(Pb.UsedCell[3, Pb.StepNum])], module) = 'ProcessOK')) and
     ((Pb.UsedCell[4,Pb.StepNum] = 0) or
     (mm.GetDigCurStrID(nArr_C_STS[ROUND(Pb.UsedCell[4, Pb.StepNum])], Module) = 'ProcessOK')) then
    begin
      Step.Flag := True;
      Step.Times := 1;
      Step.dtCurTime := NOW;
      Inc(Check.MainRateCount);
      Inc(Step.Layer);
    end
    else
    begin
      if ((Pb.UsedCell[1, Pb.StepNum] <> 0) and
        (mm.GetDigCurStrID(nArr_C_CTRL[Round(Pb.UsedCell[1, Pb.StepNum])], module) = 'Alarm')) or
        ((Pb.UsedCell[2, Pb.StepNum] <> 0) and
        (mm.GetDigCurStrID(nArr_C_CTRL[Round(Pb.UsedCell[2, Pb.StepNum])], module) = 'Alarm')) or
        ((Pb.UsedCell[3, Pb.StepNum] <> 0) and
        (mm.GetDigCurStrID(nArr_C_CTRL[Round(Pb.UsedCell[3, Pb.StepNum])], module) = 'Alarm')) or
         ((Pb.UsedCell[4,Pb.StepNum] <> 0) and
         (mm.GetDigCurStrID(nArr_C_CTRL[ROUND(Pb.UsedCell[4, Pb.StepNum])], Module) = 'Alarm')) then
        ShowAlarm(ALM_PROCESS_CELL);
      INC_TIMES;
    end;
  end;
end;

// Layer 11 : Mainshutter Open
procedure TOC1Process.P_PROCESS_MainShutterOpen;
var
  CellNum, i, j: Integer;
begin
  if (Step.Flag) then
  begin
    if Not(F_MAIN_RATE_CHECK) then
    begin
      if Step.Times >= 30 then
      begin
        EventLog('[' + ModuleName + ']' + ' Rate is not Stay Target. Can not Open Main Shutter.');
        Step.Flag := True;
        Dec(Step.Layer);
      end;
      INC_TIMES;
      Exit;
    end;

    for i := 1 to MaxCoDep do
    begin
      CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);
      // if CellNum > 0 then
      if (i = 1) and (CellNum > 0) then
      begin
        mm.SetDigID(nArr_OC1_CH_CONT[CellNum], 'ZeroThck', module);
        SLEEP(500);
        mm.SetDigID(nArr_OC1_CH_CONT[CellNum], 'ZeroThck', module);
        SLEEP(1000);
      end;
    end;

    mm.SetDigID(MAINSHUTTER_O, 'Open', module);
    SLEEP(1000);
    { for J := 1 to 6 do //ADD
      for i := 1 to MaxCoDep do
      begin
      CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);
      if CellNum > 0 then
      begin
      mm.SetDigID(nArr_CH_CONT[F_CELL_CH_NUMBER(CellNum)], 'ZeroThck', module);
      Sleep(500);
      end;
      end; }
    {
      // channel false : add (ksy) 2014. 11. 10
      for i := 1 to MaxCell do
      begin
      if (mm.GetDigSetStrID(nArr_C_HUNTING_FLG[i], module) <> 'False') then
      mm.SetDigID(nArr_C_HUNTING_FLG[i], 'False', module);
      end;
    }
    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigCurStrID(MAINSHUTTER_I, module) = 'Open') then
    begin
      EventLog('[' + ModuleName + ']' + ' Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
        ' Target Thickness Check Start.');

      DepoStartThickness := 0;

      CellNum := Round(Pb.UsedCell[1, Pb.StepNum]);
      DepoStartThickness := mm.GetAnaCurID(nArr_OC1_Ch_CUR_THICK[CellNum], module);

      EventLog('<-- Deposite Cell Start Thickness : ' + FormatFloat('0.000', DepoStartThickness)
        + 'A -->');

      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      if (mm.GetAnaSetID(VALVEOPENCLOSETIMEOUT, module) > 0) and
        (Step.Times >= mm.GetAnaSetID(VALVEOPENCLOSETIMEOUT, module)) then
        ShowAlarm(ALM_PROCESS_SHUTTER_OPEN);
      INC_TIMES;
    end;
  end;
end;

// Layer 12 : Thickness Check
procedure TOC1Process.P_PROCESS_ThicknessCheck;
var
  CellNum: Integer;
  i: Integer;
begin
  if (Step.Flag) then
  begin
    CellNum := Round(Pb.UsedCell[1, Pb.StepNum]);
    EventLog('Checking the [' + ModuleName + '] Cell #' + IntToStr(CellNum) + ' Thickness: ' +
      FormatFloat('0', Pb.TargetThickness[Pb.StepNum]) + ' A.');

    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (Step.Times >= 5) and (F_THICKNESS_CHECK) then
    begin
      mm.SetDigID(MAINSHUTTER_O, 'Close', module);
      {
        for i := 1 to MaxCell do
        begin
        if (mm.GetDigSetStrID(nArr_C_HUNTING_FLG[i], module) <> 'False') then
        mm.SetDigID(nArr_C_HUNTING_FLG[i], 'False', module);
        end; }
      EventLog('[' + ModuleName + ']' + ' Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
        ' Target Thickness Check End.');

      Step.Flag := True;
      Step.Times := 1;
      Step.dtCurTime := NOW;
      Inc(Step.Layer);
    end
    else
    begin
      if (Step.Times > 10) then
      begin
        F_SOURCE_EMPTY_ALARM_CHECK;
        // Source Empty Alarm Check.
        F_DEPOSITION_ALARM_CHECK;
        // Thickness Controller Alarm.
        F_ALIGNER_ALARM_CHECK; // Alarm..Aligner Stop Check.
        F_PROCESS_ALARM_CHECK;
        // Alarm..Zero rate check alarm after openning the main shutter.

        // HuntingCheck
        // if (mm.GetAnaSetID(HUNTINGRATECHECKTIMEOUT, Module)  <> 0) then F_PROCESS_HUNTING_CHECK;
      end;

      INC_TIMES;
    end;
  end;
end;

// Layer 13 : Mainshutter Close Check
procedure TOC1Process.P_PROCESS_MainShutterCloseCheck;
begin
  if (Step.Flag) then
  begin
    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if (mm.GetDigCurStrID(MAINSHUTTER_I, module) = 'Close') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      if (mm.GetAnaSetID(VALVEOPENCLOSETIMEOUT, module) > 0) and
        (Step.Times >= mm.GetAnaSetID(VALVEOPENCLOSETIMEOUT, module)) then
        ShowAlarm(ALM_PROCESS_SHUTTER_CLOSE);
      INC_TIMES;
    end;
  end;
end;

// Layer 14 : Cell After Check
procedure TOC1Process.P_PROCESS_CellAfterCheck;
var
  i: Integer;
begin
  if (Step.Flag) then
  begin
    for i := 1 to MaxCoDep do
    begin
      if (Pb.UsedCell[i, Pb.StepNum] <> 0) then
      begin
        mm.SetDigID(nArr_C_MODE[Round(Pb.UsedCell[i, Pb.StepNum])], 'After', module);
        mm.SetDigID(nArr_C_CTRL[Round(Pb.UsedCell[i, Pb.StepNum])], 'Run', module);
        mm.SetDigID(nArr_C_STS[Round(Pb.UsedCell[i, Pb.StepNum])], 'Idle', module);
        SLEEP(1000);
      end;
    end;
    Step.Flag := False;
    Step.Times := 1;
    Step.dtCurTime := NOW;
  end
  else
  begin
    if ((Pb.UsedCell[1, Pb.StepNum] = 0) or
      (mm.GetDigCurStrID(nArr_C_STS[Round(Pb.UsedCell[1, Pb.StepNum])], module) = 'AfterOK')) and
      ((Pb.UsedCell[2, Pb.StepNum] = 0) or
      (mm.GetDigCurStrID(nArr_C_STS[Round(Pb.UsedCell[2, Pb.StepNum])], module) = 'AfterOK')) and
      ((Pb.UsedCell[3, Pb.StepNum] = 0) or
      (mm.GetDigCurStrID(nArr_C_STS[Round(Pb.UsedCell[3, Pb.StepNum])], module) = 'AfterOK')) and
     ((Pb.UsedCell[4,Pb.StepNum] = 0) or
     (mm.GetDigCurStrID(nArr_C_STS[Round(Pb.UsedCell[4, Pb.StepNum])], Module) = 'AfterOK')) then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

// Layer 15 : Cell wait time check
procedure TOC1Process.P_PROCESS_CellWaitTimeCheck;
begin
  if (Step.Flag) then
  begin
    if (Pb.UsedCell[1, Pb.StepNum] <> Pb.UsedCell[1, Pb.StepNum + 1]) or
      (Pb.UsedCell[2, Pb.StepNum] <> Pb.UsedCell[2, Pb.StepNum + 1]) or
      (Pb.UsedCell[3, Pb.StepNum] <> Pb.UsedCell[3, Pb.StepNum + 1]) or
     (Pb.UsedCell[4, Pb.StepNum] <> Pb.UsedCell[4, Pb.StepNum + 1]) then
    begin
      EventLog('Checking The [' + ModuleName + '] Cell shutter closing time : ' +
        mm.GetAnaSetStrID(SHUTTER_CLOSE_TIME, module) + ' sec.');

      Step.Flag := False;
      Step.Times := 1;
      Step.dtCurTime := NOW;
    end
    else
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end;
  end
  else
  begin
    if (Step.Times >= mm.GetAnaSetID(SHUTTER_CLOSE_TIME, module)) then
    begin
      F_PROCESS_ShutterCheck;

      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

// Layer 16 : End step check
procedure TOC1Process.P_PROCESS_EndStepCheck;
var
  i: byte;
begin
  if (Step.Flag) then
  begin
    EventLog('Checking [' + ModuleName + '] Next Step Process!');

    for i := 1 to MaxCoDep do
    begin
      mm.SetAnaID(nArr_USEDCELL[i], 0, module);
    end;

    if (Pb.StepNum >= Pb.TotalStep) then
    begin
      mm.SetDigID(MOVE_MODE, 'RoStop', module);
      mm.SetDigID(MOVE_CTRL, 'Run', module);
      mm.SetDigID(MOVE_STS, 'Idle', module);

      SLEEP(500);
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      // if use mask change in next step, align rotation stop.
      mm.SetDigID(MOVE_MODE, 'RoStop', module);
      mm.SetDigID(MOVE_CTRL, 'Run', module);
      mm.SetDigID(MOVE_STS, 'Idle', module);

      SLEEP(500);
      Step.Flag := False;
      Step.Times := 1;
      Step.dtCurTime := NOW;
      {
        if (Pb.MaskChangeID[Pb.StepNum + 1] <> 0) then
        begin
        mm.SetDigID(MOVE_MODE, 'RoStop', module);
        mm.SetDigID(MOVE_CTRL, 'Run',    module);
        mm.SetDigID(MOVE_STS , 'Idle',   module);

        sleep(500);
        Step.Flag  := False;
        Step.Times := 1;
        Step.dtCurTime := NOW;
        end else
        begin
        Inc(Pb.StepNum);
        Step.Flag  := True;
        mm.SetDigID(RECCURSTEP , IntToStr(Pb.StepNum), module);
        Step.Layer := 5;       // Glass Check, and ramping number setting.
        end;
      }
    end;
  end
  else
  begin
    if (mm.GetDigSetStrID(MOVE_STS, module) = 'RoStopOK') then
    begin
      Inc(Pb.StepNum);
      Step.Flag := True;
      mm.SetDigID(RECCURSTEP, IntToStr(Pb.StepNum), module);
      Step.Layer := 5;
      // Glass Check. and ramping number setting.
    end
    else
    begin
      if (mm.GetAnaSetID(ALIGNERMOVETIMEOUT, module) > 0) and
        (Step.Times >= mm.GetAnaSetID(ALIGNERMOVETIMEOUT, module)) then
        ShowAlarm(ALM_PROCESS_ALIGN_ROSTOP);
      INC_TIMES;
    end;
  end;
end;

// Layer 17 : Aligner GlassLoad Position
procedure TOC1Process.P_PROCESS_Align;
begin
  if (Step.Flag) then
  begin
    if (Pb.AlignUse[Pb.StepNum] = 1) then
    begin
      if Pb.StepNum <= 1 then
      begin
        EventLog('[' + ModuleName + ']' + ' Aligner Align!');
        mm.SetAnaID(ALIGNER_XSHIFT, Pb.AlignXShift[Pb.StepNum], module);
        mm.SetAnaID(ALIGNER_YSHIFT, Pb.AlignYShift[Pb.StepNum], module);
        SLEEP(300);

        mm.SetDigID(MOVE_MODE, 'Align', module);
        mm.SetDigID(MOVE_CTRL, 'Run', module);
        mm.SetDigID(MOVE_STS, 'Idle', module);
        SLEEP(1000);

        Step.Flag := False;
        Step.Times := 1;
      end
      else
      begin
        Step.Flag := True;
        Inc(Step.Layer);
        Exit;
      end;
    end
    else
    begin
      Step.Flag := True;
      Inc(Step.Layer);
      Exit;
    end;
  end
  else
  begin
    if (mm.GetDigCurStrID(MOVE_STS, module) = 'AlignOK') then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end;
    INC_TIMES;
  end;
end;

procedure TOC1Process.P_PROCESS_AlignerGlassLoad;
begin
  if (Step.Flag) then
  begin
    if (mm.GetDigSetStrID(MOVE_STS, module) = 'RoStopOK') then
    begin
      EventLog('[' + ModuleName + '] Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
        ' Aligner glass load start.');

      mm.SetDigID(MOVE_MODE, 'GlassLoad', module);
      mm.SetDigID(MOVE_CTRL, 'Run', module);
      mm.SetDigID(MOVE_STS, 'Idle', module);
      SLEEP(1000);

      Step.Flag := False;
      Step.Times := 1;
      Step.dtCurTime := NOW;
    end;
  end
  else
  begin
    if (mm.GetDigCurStrID(MOVE_STS, module) = 'GlassLoadOK') then
    begin
      EventLog('[' + ModuleName + '] Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
        ' Aligner glass load position.');

      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      INC_TIMES;
    end;
  end;
end;

// Layer 18 : Process END
procedure TOC1Process.P_PROCESS_ProcessEnd;
begin
  mm.SetDigID(DATALOGSET, 'Disable', module);
  // 2016.03.22 KSY
  mm.SetDigID(GLASS_STATUS, 'ProcessEnd', module);

  mm.SetDigID(PM_MODE, 'Idle', module);
  mm.SetDigID(PM_CTRL, 'Idle', module);
  mm.SetDigID(PM_STS, 'ProcessOK', module);

  EventLog('[' + ModuleName + '] Auto Process END.');
end;

// ==============================================================================
// Function
// ==============================================================================

// ActionList : Process Start 시
procedure TOC1Process.F_ALL_CELL_SHUTTER(openclose: PChar);
var
  i: Integer;
begin
  for i := 1 to MaxCell do
  begin
    mm.SetDigID(nArr_C_SHUTTER_SN_O[i], openclose, module);
  end;
end;

// Layer 5 : Glass Check - Cell Recipe Loading
procedure TOC1Process.F_CellRecipe;
var
  i: byte;
  F: TFileStream;
  FullPath: string;
  CellNum: Single;
begin
  PbCell.RateStableTime := Pb.RateStableTime[Pb.StepNum];

  for i := 1 to MaxCoDep do
  begin
    if (Pb.UsedCell[i, Pb.StepNum] <> 0) then
    begin
      CellNum := Pb.UsedCell[i, Pb.StepNum];
      PbCell.CellRate := Pb.CellRate[i, Pb.StepNum];
      PbCell.AfterProcess := Pb.AfterProcess[i, Pb.StepNum];
      PbCell.StandByTemp := Pb.CellStandbyTemp[i, Pb.StepNum];
      PbCell.StandByBotTemp := Pb.CellBotStandbyTemp[i, Pb.StepNum];
      PbCell.RampingName := Pb.RampingNum[i, Pb.StepNum];
      PbCell.BotRampingName := Pb.BotRampingNum[i, Pb.StepNum];
      PbCell.ProgramName := Pb.CellProgramNum[i, Pb.StepNum];
      PbCell.DelayTime := Pb.DelayTime[i, Pb.StepNum];
      PbCell.FeedingFlag := False;
      PbCell.CodepNum := i;

      if (DirectoryExists(mm.GetHomePath + '\Recipes\CellRecipe') = False) then
      begin
        CreateDir(mm.GetHomePath + '\Recipes\CellRecipe');
        SLEEP(500);
      end;

      if (DirectoryExists(mm.GetHomePath + '\Recipes\CellRecipe\' + ModuleName) = False) then
      begin
        CreateDir(mm.GetHomePath + '\Recipes\CellRecipe\' + ModuleName);
        SLEEP(500);
      end;

      if (DirectoryExists(mm.GetHomePath + '\Recipes\CellRecipe\' + ModuleName + '\Cell' +
        IntToStr(Round(CellNum))) = False) then
      begin
        CreateDir(mm.GetHomePath + '\Recipes\CellRecipe\' + ModuleName + '\Cell' +
          IntToStr(Round(CellNum)));
        SLEEP(500);
      end;

      FullPath := mm.GetHomePath + '\Recipes\CellRecipe\' + ModuleName + '\Cell' +
        IntToStr(Round(CellNum)) + '\' + ExtractFileName(mm.GetStrSetMsgID(RECNAME, module));

      F := TFileStream.Create(FullPath, fmCreate);
      F.Write(PbCell, SizeOf(PbCell));
      F.Free;

      mm.SetStrID(nArr_C_RECIPENAME[Round(CellNum)], FullPath, module);
      SLEEP(1000);
    end;
  end;
end;

// Layer 7 : Mainshutter Close - Check
procedure TOC1Process.F_ALL_PROCESS_CELL_SHUTTER(openclose: PChar);
var
  i: Integer;
begin
  for i := 1 to MaxCell do
  begin
    if (mm.GetDigSetStrID(nArr_C_TEMPRATE_O[i], module) = 'Temp') then
      mm.SetDigID(nArr_C_SHUTTER_SN_O[i], openclose, module);
  end;
end;

// Layer 13 : Thickness Check - Check
function TOC1Process.F_THICKNESS_CHECK: Boolean;
var
  thickness_value: Single;
  CellNum, i: Integer;
begin
  result := False;

  CellNum := Round(Pb.UsedCell[1, Pb.StepNum]);

  thickness_value := mm.GetAnaCurID(nArr_OC1_Ch_CUR_THICK[CellNum], module);

  mm.SetAnaID(CURTHICKNESS, Round(FinalThickness + ((thickness_value - DepoStartThickness) * 1000)
    ), module);

  if (Pb.TargetThickness[Pb.StepNum] <= (FinalThickness + ((thickness_value - DepoStartThickness) *
    1000))) then
  begin
    result := True;
  end;
end;

// Layer 13 : Thickness Check - source empty alarm
procedure TOC1Process.F_SOURCE_EMPTY_ALARM_CHECK;
var
  i: Integer;
  RateValue, EmptyValue: array [1 .. MaxCoDep] of double;
  CellNum: Integer;
begin
  for i := 1 to MaxCoDep do
  begin
    CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);

    RateValue[i] := mm.GetAnaCurID(nArr_OC1_Ch_RATE_AVE[CellNum], module);

  end;

  for i := 1 to MaxCoDep do
  begin
    CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);
    if CellNum <> 0 then
      EmptyValue[i] := ((Pb.CellRate[i, Pb.StepNum] * mm.GetAnaSetID(SOURCEEMPTYTOLERANCE,
        module)) / 100);
  end;

  for i := 1 to MaxCoDep do
  begin
    if Pb.UsedCell[i, Pb.StepNum] <> 0 then
    begin
      if RateValue[i] <= EmptyValue[i] then
      begin
        if Check.Source_Empty_Count[i] >= 10 then
        begin

          case Round(Pb.UsedCell[i, Pb.StepNum]) of
            1:
              ShowAlarm(ALM_C1_SOURCE_EMPTY);
            2:
              ShowAlarm(ALM_C2_SOURCE_EMPTY);
            3:
              ShowAlarm(ALM_C3_SOURCE_EMPTY);
            4:
              ShowAlarm(ALM_C4_SOURCE_EMPTY);
            5:
              ShowAlarm(ALM_C5_SOURCE_EMPTY);
            6:
              ShowAlarm(ALM_C6_SOURCE_EMPTY);
//            7:
//              ShowAlarm(ALM_C7_SOURCE_EMPTY);
//            8:
//              ShowAlarm(ALM_C8_SOURCE_EMPTY);
          end;
        end
        else
        begin
          Inc(Check.Source_Empty_Count[i]);
        end;
      end
      else
      begin
        Check.Source_Empty_Count[i] := 0;
      end;
    end
    else
    begin
      Check.Source_Empty_Count[i] := 0;
    end;
  end;
end;

// Layer 13 : Thickness Check - Deposition alarm
procedure TOC1Process.F_DEPOSITION_ALARM_CHECK;
var
  i, CellNum: Integer;
  DepoSts: Array [1 .. MaxCoDep] of String;
begin
  for i := 1 to MaxCoDep do
  begin
    CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);

    DepoSts[i] := mm.GetDigCurStrID(nArr_OC1_Ch_STATE[CellNum], module);

  end;

  for i := 1 to MaxCoDep do
  begin
    if Pb.UsedCell[i, Pb.StepNum] <> 0 then
    begin
      if (DepoSts[i] = 'Stop') or (DepoSts[i] = 'Ready') then
      begin
        if (Check.DepositCount[i] >= 30) then
        begin
          ShowAlarm(ALM_PROCESS_CYGNUS_STOP);
          // Cygnus does not work.,Please check the Cygnus.
          Exit;
        end
        else
          Inc(Check.DepositCount[i]);
      end
      else
        Check.DepositCount[i] := 1;
    end;
  end;
end;

function TOC1Process.F_MAIN_RATE_CHECK: Boolean;
var
  rate_value: array [1 .. MaxCoDep] of Single;
  error_value: array [1 .. MaxCoDep] of Single;
  i, CellNum: byte;
begin
  result := False;

  for i := 1 to MaxCoDep do
  begin
    CellNum := 0;
    CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);

    rate_value[i] := mm.GetAnaCurID(nArr_OC1_Ch_RATE_AVE[CellNum], module);

    if (CellNum <> 0) then
      error_value[i] := (Pb.CellRate[i, Pb.StepNum] * (mm.GetAnaSetID(nArr_C_RATETOLERANCE[CellNum],
        module) / 100));
  end;

  if ((Pb.UsedCell[1, Pb.StepNum] = 0) or (ABS(Pb.CellRate[1, Pb.StepNum] - rate_value[1]) <=
    error_value[1])) and ((Pb.UsedCell[2, Pb.StepNum] = 0) or
    (ABS(Pb.CellRate[2, Pb.StepNum] - rate_value[2]) <= error_value[2])) and
    ((Pb.UsedCell[3, Pb.StepNum] = 0) or (ABS(Pb.CellRate[3, Pb.StepNum] - rate_value[3]) <=
    error_value[3])) and
    ((Pb.UsedCell[4, Pb.StepNum] = 0) or (ABS(Pb.CellRate[4, Pb.StepNum] - rate_value[4]) <=
    error_value[4])) then
  begin
    EventLog('Rate check Pass... Main Shutter Open <Complete> ');
    result := True;
  end;
end;

// Layer 13 : Thickness Check - Aligern Alarm
procedure TOC1Process.F_ALIGNER_ALARM_CHECK;
begin
  if (mm.GetDigCurStrID(ALIGNER_RUNSTS, module) = 'Alarm') or
    (mm.GetDigCurStrID(ALIGNER_RUNSTS, module) = 'Abort') or
    (mm.GetDigCurStrID(ALIGNER_RUNSTS, module) = 'Unknown') then
  begin
    if (Check.AlignerCount >= 10) then
    begin
      ShowAlarm(ALM_PROCESS_ALIGNER_STOP);
      // Align.Rotation,Aligner Rotation Fail.
      Exit;
    end;
    Inc(Check.AlignerCount);
  end
  else
    Check.AlignerCount := 1;
end;

// Layer 13 : Thickness Check - Process Alarm
procedure TOC1Process.F_POWER_ON_ALARM_CHECK;
var
  i: Integer;
  PwrStr: Array [1 .. 6] of String;
begin
  PwrStr[1]  := mm.GetDigCurStrID(C1_POWSTS, module);
  PwrStr[2]  := mm.GetDigCurStrID(C2_POWSTS, module);
  PwrStr[3]  := mm.GetDigCurStrID(C3_POWSTS, module);
  PwrStr[4]  := mm.GetDigCurStrID(C4_POWSTS, module);
  PwrStr[5]  := mm.GetDigCurStrID(C5_POWSTS, module);
  PwrStr[6]  := mm.GetDigCurStrID(C6_POWSTS, module);
//  PwrStr[7]  := mm.GetDigCurStrID(C1_BOT_POWSTS, module);
//  PwrStr[8]  := mm.GetDigCurStrID(C2_BOT_POWSTS, module);
//  PwrStr[9]  := mm.GetDigCurStrID(C3_BOT_POWSTS, module);
//  PwrStr[10] := mm.GetDigCurStrID(C4_BOT_POWSTS, module);

  for i := 1 to MaxCoDep do
  begin
    if (Pb.UsedCell[i, Pb.StepNum] <> 0) then
    begin
      if (PwrStr[Round(Pb.UsedCell[i, Pb.StepNum])] = 'OFF') then
      begin

        mm.SetDigID(nArr_C_CONT[Round(Pb.UsedCell[i, Pb.StepNum])], 'On', module);
        SLEEP(100);

        if (Check.PowerCount[i] >= 100) then
        begin
          case (Round(Pb.UsedCell[i, Pb.StepNum])) of
            1:
              ShowAlarm(ALM_C1_PROCESS_CELL_ON);
            2:
              ShowAlarm(ALM_C2_PROCESS_CELL_ON);
            3:
              ShowAlarm(ALM_C3_PROCESS_CELL_ON);
            4:
              ShowAlarm(ALM_C4_PROCESS_CELL_ON);
            5:
              ShowAlarm(ALM_C5_PROCESS_CELL_ON);
            6:
              ShowAlarm(ALM_C6_PROCESS_CELL_ON);
//            7:
//              ShowAlarm(ALM_C7_PROCESS_CELL_ON);
//            8:
//              ShowAlarm(ALM_C8_PROCESS_CELL_ON);
          end;
          Exit;
        end
        else
          Inc(Check.PowerCount[i]);
      end
      else
        Check.PowerCount[i] := 1;
    end;
  end;
end;

procedure TOC1Process.F_PROCESS_ALARM_CHECK;
var
  i: Integer;
  SnStr: array [1 .. MaxCell] of String;
  TempT, ArmTempT: array [1 .. MaxCell] of Single;
  Temp, ArmTemp: Single;
  CellNum: Integer;
begin
  for i := 1 to MaxCoDep do
  begin
    CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);

    SnStr[i] := mm.GetDigCurStrID(nArr_OC1_CH_SNSSTA[CellNum], module);

    if (CellNum >= 1) and (CellNum <= 8) then
    begin
      TempT[i] := mm.GetAnaCurID(nArr_C_TEMP[CellNum], module);
      ArmTempT[i] := mm.GetAnaSetID(nArr_C_ALARMTEMP[CellNum], module);
    end
    else
    begin
      TempT[i] := 0;
      ArmTempT[i] := 99999;
      Temp := 0;
      ArmTemp := 99999;
    end;
  end;

  for i := 1 to MaxCoDep do
  begin
    if Pb.UsedCell[i, Pb.StepNum] <> 0 then
    begin
      if (mm.GetDigCurStrID(CYGNUS2_COMSTA, module) = 'OFFLINE') then
      begin
        if Check.IC5_OFF_Line_Count[i] >= 30 then
        begin
          ShowAlarm(ALM_PROCESS_CYGNUS_COMSTA);
          // Cygnus.Comsts,Cygnus communication fails.
          Exit;
        end
        else
          Inc(Check.IC5_OFF_Line_Count[i]);
      end
      else
        Check.IC5_OFF_Line_Count[i] := 1;

      if SnStr[i] = 'Failed' then
      begin
        if Check.Cell_Sn_Fail_Count[i] >= 30 then
        begin
          ShowAlarm(ALM_PROCESS_CYGNUS_SENSOR);
          // Cygnus.Sensor,Cygnus Sensor fails.
        end
        else
          Inc(Check.Cell_Sn_Fail_Count[i]);
      end
      else
        Check.Cell_Sn_Fail_Count[i] := 1;
    end;
  end;

  for i := 1 to MaxCoDep do
  begin
    if ((TempT[i] > ArmTempT[i]) and (TempT[i] < 980)) then
    // or ((Temp > ArmTemp) and (Temp < 980)) then
    begin
      if Check.Cell_Temp_Alarm_Count[i] >= 30 then
      begin
        ShowAlarm(ALM_PROCESS_TEMP_HIGH);
        // Temperatue of evaporation celll is too high.
        Exit;
      end
      else
        Inc(Check.Cell_Temp_Alarm_Count[i]);
    end
    else
      Check.Cell_Temp_Alarm_Count[i] := 1;
  end;
end;

procedure TOC1Process.F_PROCESS_HUNTING_CHECK;
var
  i: Integer;
  rate_value: array [1 .. MaxCoDep] of Single;
  error_value: array [1 .. MaxCoDep] of Single;
  CellNum: Integer;
begin
  {
    for i := 1 to MaxCoDep do
    begin
    CellNum := Round(Pb.UsedCell[i , Pb.StepNum]);

    if (CellNum > 0) then
    begin
    rate_value[i]  := mm.GetAnaCurID(nArr_Ch_RATE_AVE[F_CELL_CH_NUMBER(ROUND(Pb.UsedCell[i, Pb.StepNum]))] , Module);
    error_Value[i] := (Pb.CellRate[i, Pb.StepNum] * (mm.GetAnaSetID( nArr_C_RATETOLERANCE[CellNum] , module) / 100));
    end;
    end;

    if ((Round(Pb.UsedCell[1 , Pb.StepNum]) <> 0) and (ABS(Pb.CellRate[1, Pb.StepNum] - rate_value[1]) >= error_value[1])) or
    ((Round(Pb.UsedCell[2 , Pb.StepNum]) <> 0) and (ABS(Pb.CellRate[2, Pb.StepNum] - rate_value[2]) >= error_value[2])) or
    ((Round(Pb.UsedCell[3 , Pb.StepNum]) <> 0) and (ABS(Pb.CellRate[3, Pb.StepNum] - rate_value[3]) >= error_value[3])) then
    //((Round(Pb.UsedCell[4 , Pb.StepNum]) <> 0) and (ABS(Pb.CellRate[4, Pb.StepNum] - rate_value[4]) >= error_value[4])) then
    begin
    if (Check.RateCount >= (mm.GetAnaSetID(HUNTINGRATECHECKTIMEOUT, Module)) * 10) then
    begin
    Step.Flag := True;
    EventTime := Round(Check.RateCount / 10);
    EventLog('Hunting rate check time <Complete> ');

    Step.Layer := 30;  // P_PROCESS_RateCheck
    end else
    begin
    inc(Check.RateCount);
    if Round(Check.RateCount / 10) <> EventTime then
    begin
    EventTime := Round(Check.RateCount / 10);
    EventLog('Hunting rate check time : ' + intToStr(EventTime) + ' / ' + mm.GetAnaSetStrID( HUNTINGRATECHECKTIMEOUT , module));
    end;
    end;
    end else
    Check.RateCount := 1;
  }
end;

// Layer 16 : Cell wait time check - Cell shutter check
procedure TOC1Process.F_PROCESS_ShutterCheck;
var
  i, CellNum: Integer;
begin
  for i := 1 to MaxCoDep do
  begin
    CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);

    case CellNum of
      1 .. MaxCell:
        begin
          if Pb.AfterProcess[i, Pb.StepNum] = 1 then
          // Standby Temp
          begin
            mm.SetDigID(nArr_C_SHUTTER_SN_O[CellNum], 'Close', module);
          end
          else if Pb.AfterProcess[i, Pb.StepNum] = 0 then
          // Keep Rate
          begin
            //
          end
          else if Pb.AfterProcess[i, Pb.StepNum] = 2 then
          // Power Off
          begin
            mm.SetDigID(nArr_C_SHUTTER_SN_O[CellNum], 'Close', module);
          end;
        end;
    end;
  end;
end;

procedure TOC1Process.P_PROCESS_RateCheck;
var
  i, CellNum, CellRate: Integer;
begin
  if (Step.Flag) then
  begin
    // CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);
    // CellRate := Round(Pb.CellRate[i, Pb.StepNum]);

    CellNum := Round(Pb.UsedCell[1, Pb.StepNum]);
    if (Pb.CellRate[1, Pb.StepNum] = 0) then
    begin
      EventLog('Rate Check Pass (Rate is Zero) !!');

      Step.Flag := True;
      Inc(Step.Layer);
      Exit;
    end;

    if (Pb.CellRate[1, Pb.StepNum] <> 0) then
    begin
      for i := 1 to MaxCoDep do
      begin
        case (Round(Pb.UsedCell[i, Pb.StepNum])) of
          1 .. MaxCell:
            begin
              EventLog('[' + ModuleName + ']' + ' Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
                ' rate check start.' + '<<' + ' Cell #' +
                IntToStr(Round(Pb.UsedCell[i, Pb.StepNum])) + '>>');

              mm.SetDigID(nArr_C_TEMPRATE_O[Round(Pb.UsedCell[i, Pb.StepNum])], 'Rate', module);

              EventLog('Checking the ' + '[' + ModuleName + ']' + ' Glass #' +
                mm.GetAnaSetStrID(GLASS_ID, module) + ' Cell #' +
                IntToStr(Round(Pb.UsedCell[i, Pb.StepNum])) + ' Rate : ' + FormatFloat('0.000',
                Pb.CellRate[i, Pb.StepNum]) + ' A/s.');
            end;
        end;
      end;
    end;

    Check.CheckRateCount := 0; // add 2015.05.20

    Step.Flag := False;
    Step.Times := 1;
  end
  else
  begin
    if (F_RATE_CHECK) then
    begin
      for i := 1 to MaxCoDep do
      begin
        case Round(Pb.UsedCell[i, Pb.StepNum]) of
          1 .. MaxCell:
            begin
              EventLog('[' + ModuleName + ']' + ' Glass #' + mm.GetAnaSetStrID(GLASS_ID, module) +
                ' rate check end.' + '<<' + ' Cell #' +
                IntToStr(Round(Pb.UsedCell[i, Pb.StepNum])) + '>>');
            end;
        end;
      end;
      Step.Flag := True;
      Inc(Step.Layer);

    end
    else
    begin
      if (Step.Times >= 10) then
      begin
        F_DEPOSITION_ALARM_CHECK;
        F_PROCESS_ALARM_CHECK;
        F_POWER_ON_ALARM_CHECK;
      end;

      if (Step.Times >= mm.GetAnaSetID(RATETIMEOUT, module)) then
      begin
        // 2015. 07. 10
        for i := 1 to MaxCoDep do
        begin
          case Round(Pb.UsedCell[i, Pb.StepNum]) of
            // ShowAlarm(Alarm[5]);
            1:
              ShowAlarm(ALM_C1_PROCESS_TARGET_RATE);
            2:
              ShowAlarm(ALM_C2_PROCESS_TARGET_RATE);
            3:
              ShowAlarm(ALM_C3_PROCESS_TARGET_RATE);
            4:
              ShowAlarm(ALM_C4_PROCESS_TARGET_RATE);
            5:
              ShowAlarm(ALM_C5_PROCESS_TARGET_RATE);
            6:
              ShowAlarm(ALM_C6_PROCESS_TARGET_RATE);
//            7:
//              ShowAlarm(ALM_C7_PROCESS_TARGET_RATE);
//            8:
//              ShowAlarm(ALM_C8_PROCESS_TARGET_RATE);
          end;
        end;
      end;

      INC_TIMES;
    end;
  end;
end;

procedure TOC1Process.P_PROCESS_RateStabilityTime;
var
  i, RateStableTime, EventTime: Integer;
begin
  if (Step.Flag) then
  begin
    RateStableTime := Round(Pb.RateStableTime[Pb.StepNum]);

    if (Pb.CellRate[1, Pb.StepNum] = 0) then
    begin
      EventLog('Rate Stability Check Pass (Rate is Zero) !!');

      Step.Flag := True;
      Inc(Step.Layer);

      Exit;
    end;

    EventLog('Checking the Rate stability Time: ' + FormatFloat('0', Pb.RateStableTime[Pb.StepNum])
      + ' sec.');
    Step.Flag := False;

    Step.Times := 0;
    Step.dtCurTime := NOW;
  end
  else
  begin

    if (Step.Times >= Pb.RateStableTime[Pb.StepNum]) then
    begin
      Step.Flag := True;
      Inc(Step.Layer);
    end
    else
    begin
      if EventTime <> Round(Step.Times) then
      begin
        EventLog('Checking the ' + ModuleName + ' Rate stability delay time: ' +
          IntToStr(Round(Step.Times)) + '/' + FormatFloat('0', Pb.RateStableTime[Pb.StepNum])
          + ' sec.');
        EventTime := Round(Step.Times);
        SLEEP(100);
      end;

      INC_TIMES;
    end;
  end;
end;

function TOC1Process.F_RATE_CHECK: Boolean;
var
  rate_value: array [1 .. MaxCoDep] of Single;
  error_value: array [1 .. MaxCoDep] of Single;
  i: Integer;
  CellNum, CellRate: Integer;
begin
  result := False;

  for i := 1 to MaxCoDep do
  begin
    CellNum := Round(Pb.UsedCell[i, Pb.StepNum]);

    rate_value[i] := mm.GetAnaCurID(nArr_OC1_CH_RATE_AVE[CellNum], module);

    error_value[i] := (Pb.CellRate[i, Pb.StepNum] * (mm.GetAnaSetID(nArr_C_RATETOLERANCE[CellNum],
      module) / 100));
  end;

  if ((Pb.UsedCell[1, Pb.StepNum] = 0) or (ABS(Pb.CellRate[1, Pb.StepNum] - rate_value[1]) <=
    error_value[1])) and ((Pb.UsedCell[2, Pb.StepNum] = 0) or
    (ABS(Pb.CellRate[2, Pb.StepNum] - rate_value[2]) <= error_value[2])) and
    ((Pb.UsedCell[3, Pb.StepNum] = 0) or (ABS(Pb.CellRate[3, Pb.StepNum] - rate_value[3]) <=
    error_value[3])) and
    ((Pb.UsedCell[4, Pb.StepNum] = 0) or (ABS(Pb.CellRate[4, Pb.StepNum] - rate_value[4]) <=
    error_value[4])) then
  begin
    if (Check.CheckRateCount >= mm.GetAnaSetID(TOLERANCECHECKTIME, module)) then
    begin
      result := True;
      EventLog('Cell #' + IntToStr(CellNum) + ' Tolerance check time : ' +
        IntToStr(Check.CheckRateCount) + ' / ' + mm.GetAnaSetStrID(TOLERANCECHECKTIME, module) +
        ' <Complete> ');
    end
    else
    begin
      Inc(Check.CheckRateCount);
      EventLog('Cell Rate Tolerance check time : ' + IntToStr(Check.CheckRateCount) + ' / ' +
        mm.GetAnaSetStrID(TOLERANCECHECKTIME, module));
    end;
  end
  else
  begin
    Check.CheckRateCount := 1;
  end;
end;

end.
