unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Menus, ComCtrls, Spin;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    ButtonCombo: TButton;
    ButtonStep: TButton;
    LabelTime: TLabel;
    LabelCount: TLabel;
    SpinEditStep: TSpinEdit;
    TimerCompute: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure ButtonComboClick(Sender: TObject);
    procedure ButtonStepClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure TimerComputeStartTimer(Sender: TObject);
    procedure TimerComputeStopTimer(Sender: TObject);
    procedure TimerComputeTimer(Sender: TObject);
    procedure TimerDrawTimer(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}
//chaos game!!!
//idea: have XXX many point object in an array
//iterate the array with a randomized matrix operation where the position of every point is changed
//draw point in point space, translate to canvas space
//maybe keep track of if the point changed places and then end loop when no movement (attractor)

const
  ParticleNumber = 262144;
  Dimensions = 3;  //dimensions of the particle space, currently 2
  glClearColor = $FFEEDD;
  glParticleShadingColor = $1357ff;
                          //BBGGRR
type
  //augmented vector and matrix
  tVector = array[1 .. Dimensions+1] of REAL;
  tMatrix = array[1 .. Dimensions+1] of array[1 .. Dimensions+1] of REAL;
  tParticle = record
    pos:tVector;
    //one:REAL;
    color:TColor;
  end;
  tParticleArray = array[1 .. ParticleNumber] of tParticle;

var
  globalArray:tParticleArray;
  glMatrix1,glMatrix2,glMatrix3,glMatrix4:tMatrix;
  glIterCount:CARDINAL;
  glStepsLeft:CARDINAL;

  glmsTimeLog:QWord;
  glIsComputing:BOOLEAN;
  glIsDrawing:BOOLEAN;
  glIsFinished:BOOLEAN;
  glIsLimited:BOOLEAN;

//==============================================================================
//       captions stuff
//------------------------------------------------------------------------------
procedure UpdateLabels;
begin
  Form1.LabelCount.Caption := 'Iterations: ' + UIntToStr(glIterCount);
  Form1.LabelCount.Top := Form1.Button1.Top + (Form1.Button1.Height-Form1.LabelCount.Height+1) DIV 2;
  Form1.LabelTime.Caption := ('Latest Draw Time: ' + UIntToStr(glmsTimeLog) + 'ms');
  Form1.LabelTime.Left := Form1.Width-Form1.LabelTime.Width;
  Form1.LabelCount.Refresh;
  Form1.LabelTime.Refresh;
end;

procedure UpdateForm1Caption;
var str:STRING;
begin
  str := '';
  if(glIsComputing)
    then str += 'Iterating...   ';
  if(glIsDrawing)
    then str += 'Drawing...   ';
  if(str='')
    then str := 'Idle...   ';
  Form1.Caption := str;
end;

function getInverseColor(col:TColor):TColor;
var r,g,b:BYTE;
begin
   r := 255 - col mod 256;
   g := 255 - (col DIV 256) mod 256;
   b := 255 - (col DIV (256*256)) mod 256;
   Result := r + 256*g + 256*256*b;
end;

procedure setFontColor;
begin
  Form1.LabelCount.Font.Color:=getInverseColor(glClearColor);
  Form1.LabelTime.Font.Color:=getInverseColor(glClearColor);
  Form1.SpinEditStep.Font.Color:=clBlack;
end;

//==============================================================================
//       math stuff
//------------------------------------------------------------------------------
function min(v1,v2:REAL):REAL;
begin
  if(v1<v2)
    then Result := v1
    else Result := v2;
end;

function max(v1,v2:REAL):REAL;
begin
  if(v1>v2)
    then Result := v1
    else Result := v2;
end;

function getLargestAbsoluteEigenvalue(mat:tMatrix):REAL;
var Re,Im:REAL;
begin
  Re := (mat[1][1]+mat[2][2])/2;
  Im := Re*Re-(mat[1][1]*mat[2][2]-mat[1][2]*mat[2][1]);
  if(Im>=0)
    then Result:=max(abs(Re+sqrt(Im)),abs(Re-sqrt(Im)))
    else Result:=sqrt(mat[1][1]*mat[2][2]-mat[1][2]*mat[2][1]);
end;

procedure scalarMultiplyBaseMatrix(VAR mat:tMatrix; scalar:REAL);
var i,j:BYTE;
begin
  for i := 1 to Dimensions do
    for j := 1 to Dimensions do
      mat[i][j] := mat[i][j]*scalar;
end;

function getDepthColor(val:REAL):TColor;
//                  val is the value the color is dependant on
const base = 0.10;  //0<base<1 prevents black
                   //base>=1 makes all particles have the shading color
var z:REAL;
    r,g,b:BYTE;
begin
  z := (max(-1,min(val,1))+1)/2; //z in [0,1]
  z := max(z,min(base,1));              //z in [base,1]
  r := round((glParticleShadingColor mod 256)*z);
  g := round(((glParticleShadingColor DIV 256) mod 256)*z);
  b := round(((glParticleShadingColor DIV (256*256)) mod 256)*z);
  Result := r + 256*g + 256*256*b;
end;

//procedure multiplyMatrix()

function getRandomParticle:tParticle;
var res:tParticle;
    i:BYTE;
    z:REAL;
begin
  for i := 1 to Dimensions do res.pos[i] := Random*2-1;
  res.pos[Dimensions+1] := 1;
  res.color := getDepthColor(res.pos[3]);
  Result := res;
end;

procedure setRandomParticleArray;
var
  i:CARDINAL;
  res:tParticleArray;
begin
  for i := 1 to ParticleNumber do begin
    res[i] := getRandomParticle;
  end;
  globalArray := res;
end;

procedure setRandomMatrix(VAR mat:tMatrix);
var i,j:BYTE;
const risk = 0.5;
begin
  for i := 1 to Dimensions do
    for j := 1 to Dimensions+1 do                         //here soon factorization and multiply
      mat[i][j] := 2*Random-1;
  for i := 1 to Dimensions do
    mat[Dimensions+1][i] := 0;
  mat[Dimensions+1][Dimensions+1] := 1;
  scalarMultiplyBaseMatrix(mat,risk/getLargestAbsoluteEigenvalue(mat));
end;

procedure setRandomAllMatrices;
begin
  setRandomMatrix(glMatrix1);
  setRandomMatrix(glMatrix2);
  setRandomMatrix(glMatrix3);
  setRandomMatrix(glMatrix4);
end;

procedure applyTransform(VAR p:tParticle);
var
  mat:tMatrix;
  newpos:tVector;
  z:REAL;
  i,j:BYTE;
begin
  case Random(4) of                 //later choose from n Matrices
    0: begin
         mat := glMatrix1;
         //p.color:=clRed;
       end;
    1: begin
         mat := glMatrix2;
         //p.color:=clBlue;
       end;
    2: begin
         mat := glMatrix3;
         //p.color:=clLime;
       end;
    3: begin
         mat := glMatrix4;
         //p.color:=clYellow;
       end;

  end;
  //matrix multiplication
  for i := 1 to Dimensions do newpos[i] := 0;
  for i := 1 to Dimensions do
    for j := 1 to Dimensions+1 do newpos[i] += mat[i][j]*p.pos[j];

  //assign result
  for i := 1 to Dimensions do p.pos[i] := newpos[i];
  p.color:=getDepthColor(p.pos[3]);
end;

procedure TransformArray(var a:tParticleArray);
var
  i:CARDINAL;
begin
  //Form1.TimerCompute.Enabled:=false;
  if(glIsFinished)
    then begin
      glStepsLeft-=1;
      glIsFinished:=false;
      Application.ProcessMessages;
      for i := 1 to Length(a) do applyTransform(a[i]);
      Application.ProcessMessages;
      glIterCount:=glIterCount+1;
      glIsFinished:=true;
    end;
end;
//==============================================================================
//       draw stuff
//------------------------------------------------------------------------------
procedure CanvasFillWithColor(c:TCanvas;col:TColor);
begin
  Application.ProcessMessages;
  Form1.Color:=col;
  Application.ProcessMessages;
  c.Brush.Color:=col;
  Application.ProcessMessages;
  c.Pen.Color:=col;
  Application.ProcessMessages;
  c.Rectangle(0,0,Form1.Width,Form1.Height);
  Application.ProcessMessages;
end;

procedure DrawParticle(p:tParticle; c:TCanvas; sizeconstraint:REAL);
begin
  //c.Pixels[round(c.Width/2+sizeconstraint*p.x/2),round(c.Height/2-sizeconstraint*p.y/2)] := p.color;
  c.Brush.Color:=p.color;
  c.Pen.Color:=p.color;
  c.Ellipse(round(c.Width/2+sizeconstraint*p.pos[1]/3)-1,round(c.Height/2-sizeconstraint*p.pos[2]/3)-1,round(c.Width/2+sizeconstraint*p.pos[1]/3)+1,round(c.Height/2-sizeconstraint*p.pos[2]/3)+1);
end;

procedure DrawArray(a:tParticleArray; c:TCanvas);
var
  i:CARDINAL;
  bound:REAL;
  time:QWord;
begin
  time := GetTickCount64;
  CanvasFillWithColor(c,glClearColor);
  bound := min(c.Width/2,c.Height/2);
  Application.ProcessMessages;
  for i := 1 to Length(a) do DrawParticle(a[i],c,bound);
  Application.ProcessMessages;
  glmsTimeLog:=GetTickCount64-time;
end;
//==============================================================================
//       misc stuff
//------------------------------------------------------------------------------
procedure Init;
begin
  CanvasFillWithColor(Form1.Canvas,glClearColor);
  setRandomParticleArray;
  setRandomAllMatrices;
  glIterCount:=0;
  glmsTimeLog:=0;
  Application.ProcessMessages;
  UpdateLabels;
end;

procedure freezeButtons;
begin
  Form1.Button1.Enabled:=false;
  Form1.Button2.Enabled:=false;
  Form1.Button3.Enabled:=false;
  Form1.ButtonStep.Enabled:=false;
  Form1.ButtonCombo.Enabled:=false;
end;

procedure reheatButtons;
begin
  Form1.Button1.Enabled:=true;
  Form1.Button2.Enabled:=true;
  Form1.Button3.Enabled:=true;
  Form1.ButtonStep.Enabled:=true;
  Form1.ButtonCombo.Enabled:=true;
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  Randomize;
  Form1.Width:=800;
  Form1.Height:=800;
  Form1.Position:=poDesktopCenter;
  Form1.TimerCompute.Interval:=25;
  Init;
  Form1.TimerCompute.Enabled:=false;
  glIsComputing:=false;
  glIsDrawing:=false;
  glIsFinished:=true;
  glIsLimited:=false;
  setFontColor;
  UpdateForm1Caption;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  UpdateLabels;
  setFontColor;
  Form1.ButtonStep.Top:=Form1.Height-10-Form1.ButtonStep.Height;
  Form1.SpinEditStep.Top:=Form1.ButtonStep.Top+(Form1.ButtonStep.Height-Form1.SpinEditStep.Height) DIV 2;
  Form1.ButtonCombo.Left:=Form1.Width-10-Form1.ButtonCombo.Width;
  Form1.ButtonCombo.Top:=Form1.Height-10-Form1.ButtonCombo.Height;
end;

procedure TForm1.TimerComputeStartTimer(Sender: TObject);
begin
  glIsComputing:=true;
  Form1.Button1.Caption:='Turn Off';
  UpdateForm1Caption;
end;

procedure TForm1.TimerComputeStopTimer(Sender: TObject);
begin
  glIsComputing:=false;
  Form1.Button1.Caption:='Turn On';
  UpdateForm1Caption;
end;

procedure TForm1.TimerComputeTimer(Sender: TObject);
begin
  if (glStepsLeft>0) OR NOT glIsLimited then begin
    TransformArray(globalArray);
    UpdateLabels;
  end
  else begin
    Form1.TimerCompute.Enabled:=false;
    glStepsLeft:=0;
    glIsLimited:=false;
    glIsDrawing:=true;
    UpdateForm1Caption;
    DrawArray(globalArray,Form1.Canvas);
    glIsDrawing:=false;
    UpdateForm1Caption;
    UpdateLabels;
    reheatButtons;
  end;
end;

procedure TForm1.TimerDrawTimer(Sender: TObject);
begin
  DrawArray(globalArray,Form1.Canvas);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Form1.TimerCompute.Enabled:=NOT Form1.TimerCompute.Enabled;
end;

procedure TForm1.Button2Click(Sender: TObject);
var buf:BOOLEAN;
begin
  freezeButtons;
  buf := Form1.TimerCompute.Enabled;
  Form1.TimerCompute.Enabled:=false;
  Application.ProcessMessages;
  Init;
  glStepsLeft:=0;
  Application.ProcessMessages;
  Form1.TimerCompute.Enabled:=buf;
  UpdateForm1Caption;
  reheatButtons;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  freezeButtons;
  glIsDrawing:=true;
  UpdateForm1Caption;
  DrawArray(globalArray,Form1.Canvas);
  glIsDrawing:=false;
  UpdateForm1Caption;
  UpdateLabels;
  reheatButtons;
end;

procedure TForm1.ButtonComboClick(Sender: TObject);
begin
  freezeButtons;
  Form1.TimerCompute.Enabled:=false;
  Init;
  glStepsLeft:=Form1.SpinEditStep.Value;
  glIsLimited:=true;
  Form1.TimerCompute.Enabled:=true;
end;

procedure TForm1.ButtonStepClick(Sender: TObject);
begin
  freezeButtons;
  Form1.TimerCompute.Enabled:=false;
  glStepsLeft:=Form1.SpinEditStep.Value;
  glIsLimited:=true;
  Form1.TimerCompute.Enabled:=true;
end;

end.

