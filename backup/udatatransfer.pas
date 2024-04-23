unit uDataTransfer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  TAGraph, TASeries, DateUtils;

type

  TCountTimer = class
  public
    lastTime:TDateTime;
    currTime:TDateTime;
    deltaTime:real;

    constructor Create;
    procedure calcDeltaTime;
  end;

  TDataPort = class
    public
    dTimerRef:^TCountTimer;
    cTime:real;
    dataPoint:real;
    updFreq:real;
    procedure Run;
    procedure Purge;
  end;

  TGenerator = class
  public
    active:boolean;
    needUpdate:boolean;
    cTime:real;
    dTimerRef:^TCountTimer;
    dPortRef:^TDataPort;
    gType:integer; //0 - sin, 1 - teeth, 2 - saw
    amp, freq, period, freqShift, freq2:real;
    cValue, cPerValue:Real;
    periodDir:real;
    constructor Create(nGType:integer; nAmp:real; nFreq:real; nFShift:real; nFreq2:real);
    constructor Update(nGType:integer; nAmp:real; nFreq:real; nFShift:real; nFreq2:real);
    procedure Run;
    procedure ToggleState;
    function calcGenFunc(tm:real; perValue:real):real;
  end;

  TProcessor = class
  public
     active:boolean;
     cDataPoint:integer;
     needUpdate:boolean;
     cTime:real;
     dTimerRef:^TCountTimer;
     dPortRef:^TDataPort;
     dataBuffer:integer;
     dataStorage:array of real;
     constructor Create(nDataBuffer:integer);
     procedure refreshSettings(nDataBuffer:integer);
     procedure Run;
     procedure ToggleState;
  end;



  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Chart1: TChart;
    cbGType: TComboBox;
    cbCurrGen: TComboBox;
    edAmplitude: TEdit;
    edBufSize1: TEdit;
    edFreq1: TEdit;
    edFreq2: TEdit;
    edNGens: TEdit;
    edUpdFreq: TEdit;
    edPhShift: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    lbGenStatus: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    lbDispStatus: TLabel;
    seriesSignal: TLineSeries;
    Panel1: TPanel;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure cbCurrGenChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure RunObjects;
    procedure Timer1Timer(Sender: TObject);
    procedure UpdateGenerator(genToUpdate:integer);
    procedure UpdateDisplay;
    procedure DisplayToSeries;
    procedure UpdateStateLabels;
    procedure ShowGeneratorData(genToShow:integer);
  private

  public

  end;

var
  Form1: TForm1;
  Generators:array of TGenerator;
  Timer:TCountTimer;
  Port:TDataPort;
  Display:TProcessor;
  stopWork:boolean=false;
  activeGen:integer=-1;

implementation

{$R *.lfm}

{ TTimer }
constructor TCountTimer.Create;
begin
  lastTime:=Now;
  currTime:=Now;
  deltaTime:=0;
end;

procedure TCountTimer.calcDeltaTime;
begin
  currTime:=Now;
  deltaTime:=MilliSecondsBetween(currTime, lastTime)/1000;
  lastTime:=currTime;
end;

{TDataPort}

procedure TDataport.Run;
begin

end;

procedure TDataport.Purge;
begin
  dataPoint:=0;
end;

{ TGenerator }
constructor TGenerator.Create(nGType:integer; nAmp:real; nFreq:real; nFShift:real; nFreq2:real);
begin
  active:=false;
  Update(nGType, nAmp, nFreq, nFShift, nFreq2);
end;

constructor TGenerator.Update(nGType:integer; nAmp:real; nFreq:real; nFShift:real; nFreq2:real);
begin
  needUpdate:=false;
  gType:=nGType;
  amp:=nAmp; freq:=nFreq; freqShift:=nFShift; freq2:=nFreq2;
  if (freq<>0) then period:=1 / freq else period:=1;
end;

procedure TGenerator.Run;
var overPer:real;
begin
  if (active) then
  begin
    if (periodDir = 0) then periodDir:=1;
    cTime:=cTime+dTimerRef^.deltaTime;
    cPerValue:=cPerValue+dTimerRef^.deltaTime;
    overPer:=period - cPerValue;
    if (overPer<0) then
    begin
      cPerValue:=abs(overPer);
      periodDir:=periodDir*(-1);;
    end;
    cValue:=calcGenFunc(cTime,cPerValue);
    dPortRef^.dataPoint:=dPortRef^.dataPoint+cValue;
  end;
end;

function TGenerator.calcGenFunc(tm:real; perValue:real):real;
var cRes, perPart:real;
begin
  if (gType=0) then
    result:=amp*sin(freq*tm+freqShift);
  if (gType=1) then
  begin
    cRes:=sin(freq*tm+freqShift);
    if (cRes>=0) then result:=amp
    else Result:=-amp;
  end;
  if (gType=2) then
  begin
    perPart:=perValue / period;
    if (periodDir>0) then
      Result:= perPart*(2*amp) - amp
    else
      Result:= (1-perPart)*(2*amp) - amp
  end;
end;

procedure TGenerator.ToggleState;
begin
  if (active) then
  begin
    active:=False;
  end
  else
  begin
    active:=True;
    needUpdate:=true;
  end;
end;

{ TProcessor }
constructor TProcessor.Create(nDataBuffer:integer);
begin
  active:=false;
  refreshSettings(nDataBuffer);
end;

procedure TProcessor.refreshSettings(nDataBuffer:integer);
begin
  needUpdate:=false;
  dataBuffer:=nDataBuffer;
  SetLength(dataStorage,dataBuffer);
end;

procedure TProcessor.Run;
var i:integer;
begin
  if (active) then
  begin
    if (cDataPoint>High(dataStorage)) then
    begin
      cDataPoint:=High(dataStorage);
      for i:=1 to High(dataStorage) do
        dataStorage[i-1]:=dataStorage[i];
    end;
    dataStorage[cDataPoint]:=dPortRef^.dataPoint;
    cDataPoint:=cDataPoint+1;
  end;
end;

procedure TProcessor.ToggleState;
begin
  if (active) then
  begin
    active:=False;
  end
  else
  begin
    active:=True;
    needUpdate:=true;
  end;
end;

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  Generators[activeGen].ToggleState;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Display.ToggleState;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  Port.updFreq:=StrToFloat(edUpdFreq.Text);
end;

procedure TForm1.Button4Click(Sender: TObject);
var nGens,i:integer;
begin
  cbCurrGen.Items.Clear;
  nGens:=Length(Generators);
  if (nGens>0) then
  for i:=0 to nGens-1 do
  begin
    FreeAndNil(Generators[i]);
  end;
  nGens:=StrToInt(edNGens.Text);
  SetLength(Generators,nGens);
  if (nGens>0) then
  for i:=0 to nGens-1 do
  begin
    Generators[i]:=TGenerator.Create(0,1,1,0,0);
    Generators[i].dTimerRef:=@Timer;
    Generators[i].dPortRef:=@Port;
    cbCurrGen.Items.Add(inttostr(i+1));
  end;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  UpdateGenerator(activeGen);
end;

procedure TForm1.cbCurrGenChange(Sender: TObject);
begin
  activeGen:=cbCurrGen.ItemIndex;
  ShowGeneratorData(activeGen);
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  stopWork:=true;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Generator:=TGenerator.Create(0,0,0,0,0);
  Display:=TProcessor.Create(0);
  Timer:=TCountTimer.Create;
  Port:=TDataPort.Create;

  Generator.dTimerRef:=@Timer;
  Display.dTimerRef:=@Timer;
  Port.dTimerRef:=@Timer;

  Generator.dPortRef:=@Port;
  Display.dPortRef:=@Port;
end;

procedure TForm1.RunObjects;
var i,nGens:integer;
begin
  ShowMessage('Starting Main Objects');
  while (true) do
  begin

    nGens:=Length(Generators);

    if (nGens>0) then
    for i:=0 to nGens-1 do
    if (Generators[i].needUpdate) then UpdateGenerator(i);

    if (Display.needUpdate) then UpdateDisplay;

    Timer.calcDeltaTime;

    Port.Purge;

    if (nGens>0) then
    for i:=0 to nGens-1 do Generators[i].Run;
    Port.Run;
    Display.Run;

    DisplayToSeries;
    UpdateStateLabels;

    Application.ProcessMessages;

    if (stopWork) then
    begin
      ShowMessage('Breaking work cycle');
      break;
    end;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled:=false;
  RunObjects;
end;

procedure TForm1.UpdateGenerator(genToUpdate:integer);
var a,f1,f2,fs:real;
    tp:integer;
begin
  tp:=cbGType.ItemIndex;
  f1:=StrToFloat(edFreq1.Text);
  f2:=StrToFloat(edFreq2.Text);
  fs:=StrToFloat(edPhShift.Text);
  a :=StrToFloat(edAmplitude.Text);
  Generators[genToUpdate].Update(tp,a,f1,fs,f2);
end;

procedure TForm1.UpdateDisplay;
var bs:integer;
begin
  bs:=strtoint(edBufSize1.Text);
  Display.refreshSettings(bs);
end;

procedure TForm1.DisplayToSeries;
var i:integer;
begin
  seriesSignal.Clear;
  for i:=0 to Display.dataBuffer-1 do
  begin
    seriesSignal.AddXY(i,Display.dataStorage[i]);
  end;
end;

procedure TForm1.UpdateStateLabels;
begin
  if (activeGen>-1) then
  if Generators[activeGen].active then lbGenStatus.Caption:='Status: ON' else lbGenStatus.Caption:='Status: OFF';

  if Display.active then lbDispStatus.Caption:='Status: ON' else lbDispStatus.Caption:='Status: OFF';
end;

procedure TForm1.ShowGeneratorData(genToShow:integer);
begin
  if (activeGen>-1) then
  begin
    cbGType.ItemIndex:=Generators[activeGen].gType;
    edAmplitude.Text:=FloatToStr(Generators[activeGen].amp);
    edFreq1.Text:=FloatToStr(Generators[activeGen].freq);
    edFreq2.Text:=FloatToStr(Generators[activeGen].freq2);
    edPhShift.Text:=FloatToStr(Generators[activeGen].freqShift);
  end;
end;

end.

