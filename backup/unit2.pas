unit Unit2;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Spin, ComCtrls, Arrow, Math;
const
  ParticleNumber = 88888;
  Dimensions = 3;  //dimensions of the particle space, currently 2
  glClearColor = $050d14;             //rrggbb
  glParticleShadingColor = $ff2020;

type
  tVector = array[1 .. Dimensions+1] of REAL;
  tMatrix = array[1 .. Dimensions+1] of array[1 .. Dimensions+1] of REAL;
  tParticle = record
    pos:tVector;
    //one:REAL;
    color:TColor;
  end;
  tParticleArray = array[1 .. ParticleNumber] of tParticle;


  { TForm2 }

  TForm2 = class(TForm)
    ArrowRight: TArrow;
    ArrowLeft: TArrow;
    ArrowUp: TArrow;
    ArrowDown: TArrow;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    ButtonOrderMatrix: TButton;
    ButtonZoomIn: TButton;
    ButtonZoomReset: TButton;
    ButtonZoomOut: TButton;
    ButtonRenderLoop: TButton;
    ButtonReset: TButton;
    ButtonMatrix: TButton;
    ButtonCombo: TButton;
    ButtonResetHorizontal: TButton;
    ButtonResetVertical: TButton;
    ButtonStep: TButton;
    LabelDVN: TLabel;
    LabelCam: TLabel;
    LabelZoom: TLabel;
    LabelCount: TLabel;
    LabelTime: TLabel;
    ListBoxMatrix: TListBox;
    SpinEditStep: TSpinEdit;
    TimerNew: TTimer;
    TimerRender: TTimer;
    TimerCompute: TTimer;
    procedure ArrowDownClick(Sender: TObject);
    procedure ArrowLeftClick(Sender: TObject);
    procedure ArrowRightClick(Sender: TObject);
    procedure ArrowUpClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure ButtonComboClick(Sender: TObject);
    procedure ButtonMatrixClick(Sender: TObject);
    procedure ButtonOrderMatrixClick(Sender: TObject);
    procedure ButtonRenderLoopClick(Sender: TObject);
    procedure ButtonResetClick(Sender: TObject);
    procedure ButtonResetHorizontalClick(Sender: TObject);
    procedure ButtonResetVerticalClick(Sender: TObject);
    procedure ButtonStepClick(Sender: TObject);
    procedure ButtonZoomInClick(Sender: TObject);
    procedure ButtonZoomOutClick(Sender: TObject);
    procedure ButtonZoomResetClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormResize(Sender: TObject);
    procedure PaintBoxPaint(Sender: TObject);
    procedure TimerComputeStartTimer(Sender: TObject);
    procedure TimerComputeStopTimer(Sender: TObject);
    procedure TimerComputeTimer(Sender: TObject);
    procedure TimerNewTimer(Sender: TObject);
    procedure TimerRenderTimer(Sender: TObject);
  private

  public

  end;

var
  Form2: TForm2;
  globalArray:tParticleArray;
  camYawAngle:REAL;
  camPitchAngle:REAL;
  camScale:REAL;

implementation
uses Unit1;

{$R *.lfm}
//chaos game!!!
//idea: have XXX many point object in an array
//iterate the array with a randomized matrix operation where the position of every point is changed
//draw point in point space, translate to canvas space
//maybe keep track of if the point changed places and then end loop when no movement (attractor)


var
  glMatrix1,glMatrix2,glMatrix3:tMatrix;
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
  Form2.LabelCount.Caption := 'Iterations: ' + UIntToStr(glIterCount);
  Form2.LabelTime.Caption := ('Draw Time: ' + UIntToStr(glmsTimeLog) + 'ms');
  Form2.LabelCount.Refresh;
  Form2.LabelTime.Refresh;
end;

procedure UpdateForm2Caption;
var str:STRING;
begin
  str := '';
  if(glIsComputing)
    then str += 'Iterating...   ';
  if(glIsDrawing)
    then str += 'Drawing...   ';
  if(str='')
    then str := 'Idle...   ';
  Form2.Caption := str;
end;

function getInverseColor(col:TColor):TColor;
var r,g,b:BYTE;
begin
   r := 255 - col mod 256;
   g := 255 - (col DIV 256) mod 256;
   b := 255 - (col DIV (256*256)) mod 256;
   Result := r + 256*g + 256*256*b;
end;

function RGBtoBGR(col:TColor):TColor;
var r,g,b:BYTE;
begin
  r := col mod 256;
  g := (col DIV 256) mod 256;
  b := (col DIV (256*256)) mod 256;
  Result := b + 256*g + 256*256*r;
end;

procedure setFontColor;
begin
  Form2.LabelCount.Font.Color:=clBlack;
  Form2.LabelTime.Font.Color:=clBlack;
  Form2.SpinEditStep.Font.Color:=clBlack;
end;

function getDepthColor(val:REAL):TColor;
//                  val is the value the color is dependant on
const base = 0.0;  //0<base<1 prevents true black
                   //base>=1 makes all particles have the shading color
var z:REAL;
    r,g,b:BYTE;
begin
  z := (max(-1.0,min(val,1.0))+1)/2; //z in [0,1]
  z := z*(1-base)+base;              //z in [base,1]
  r := round((glParticleShadingColor mod 256)*z);
  g := round(((glParticleShadingColor DIV 256) mod 256)*z);
  b := round(((glParticleShadingColor DIV (256*256)) mod 256)*z);
  Result := r + 256*g + 256*256*b;
end;

//==============================================================================
//       math stuff
//------------------------------------------------------------------------------

function MatrixMultiplication(left,right:tMatrix):tMatrix;
var row,col,ind:BYTE;
    mat:tMatrix;
begin
  for row := 1 to Dimensions+1 do
    for col := 1 to Dimensions+1 do begin
      //init to zero
      mat[row][col]:=0.0;
      //dot product of row and column vectors
      for ind := 1 to Dimensions+1 do
        mat[row][col] += left[row][ind]*right[ind][col];
    end;
  Result:=mat;
end;

function getRandomParticle:tParticle;
var res:tParticle;
    i:BYTE;
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

procedure setIdentity(VAR mat:tMatrix);
var i,j:BYTE;
begin
  for i := 1 to Dimensions+1 do
    for j := 1 to Dimensions+1 do
      mat[i][j] := 0.0;
  for i := 1 to Dimensions+1 do
    mat[i][i] := 1.0;
end;

procedure setRandomTranslation(VAR mat:tMatrix);
const radius = 1;
var i:BYTE;
    ran:REAL;
begin
  setIdentity(mat);
  for i := 1 to Dimensions do begin
    ran := (Random*2-1);
    mat[i][Dimensions+1]:=sqrt(abs(ran))*sign(ran)*radius;
  end;
end;

procedure setRandom3DShear(VAR mat:tMatrix);
var bound:BYTE;
    XY,XZ,YZ:tMatrix;
begin
  bound := min(Dimensions,3);
  setIdentity(XY);
  setIdentity(XZ);
  setIdentity(YZ);

  case bound of
    0,1: ;
      2: begin
           XZ[1][2]:=Random-1;
           YZ[2][1]:=Random-1;
         end;
      3: begin
           XY[1][3]:=Random-1;
           XY[2][3]:=Random-1;
           XZ[1][2]:=Random-1;
           XZ[3][2]:=Random-1;
           YZ[2][1]:=Random-1;
           YZ[3][1]:=Random-1;
         end;
  else   ShowMessage('There might be a problem (Random Shear Matrix)');
  end;

  mat:=MatrixMultiplication(YZ,MatrixMultiplication(XZ,XY));
end;

procedure setRandom3DRotation(VAR mat:tMatrix);
var bound:BYTE;
    x,y,z:tMatrix;
    rx,ry,rz:REAL;
begin
  bound:=min(Dimensions,3);
  setIdentity(mat);
  setIdentity(x);
  setIdentity(y);
  setIdentity(z);
  rx:=Random*2*Pi;
  ry:=Random*2*Pi;
  rz:=Random*2*Pi;

  case bound of
    0,1: ;
      2: begin
           z[1][1]:=cos(rz);
           z[1][2]:=-sin(rz);
           z[2][1]:=sin(rz);
           z[2][2]:=cos(rz);
         end;
      3: begin
           x[2][2]:=cos(rx);
           x[2][3]:=-sin(rx);
           x[3][2]:=sin(rx);
           x[3][3]:=cos(rx);

           y[3][3]:=cos(ry);
           y[3][1]:=-sin(ry);
           y[1][3]:=sin(ry);
           y[1][1]:=cos(ry);

           z[1][1]:=cos(rz);
           z[1][2]:=-sin(rz);
           z[2][1]:=sin(rz);
           z[2][2]:=cos(rz);
         end;
  else   ShowMessage('There may be a problem (Random Rotation Matrix)');
  end;

  mat:=MatrixMultiplication(z,MatrixMultiplication(y,x));
end;

procedure setRandomScale(VAR mat,translation:tMatrix);
const min = 0.6;
      max = 0.8;
var i:BYTE;
    s:SHORTINT;
begin
  setIdentity(mat);
  for i := 1 to Dimensions do begin
    s:=sign(translation[i][Dimensions+1]);
    if(s=0) then s:=1;
    mat[i][i]:=s*(Random*(max-min)+min)*(1-abs(translation[i][Dimensions+1])/(1+abs(translation[i][Dimensions+1])));
  end;
end;

procedure setRandomMatrix3D(VAR mat:tMatrix);
var i:BYTE;
    translation,shear,rotation,scale:tMatrix;
begin
  setRandomTranslation(translation);
  setRandom3DShear(shear);
  setRandom3DRotation(rotation);
  setRandomScale(scale,translation);

  mat:=MatrixMultiplication(scale,MatrixMultiplication(rotation,MatrixMultiplication(shear,translation)));

  for i := 1 to Dimensions do
    mat[Dimensions+1][i] := 0;
  mat[Dimensions+1][Dimensions+1] := 1;
end;

procedure setRandomAllMatrices;
begin
  setRandomMatrix3D(glMatrix1);
  setRandomMatrix3D(glMatrix2);
  setRandomMatrix3D(glMatrix3);
end;

procedure applyTransform(VAR p:tParticle);
var
  mat:tMatrix;
  newpos:tVector;
  i,j:BYTE;
begin
  case Random(3) of
    0: begin
         mat := glMatrix1;
       end;
    1: begin
         mat := glMatrix2;
       end;
    2: begin
         mat := glMatrix3;
       end;
  else ShowMessage('applyTransform Random(3) error');
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
procedure DrawArray;
var
  time:QWord;
begin
  time := GetTickCount64;
  Application.ProcessMessages;
  RenderParticles;
  Application.ProcessMessages;
  glmsTimeLog:=GetTickCount64-time;
end;
//==============================================================================
//       misc stuff
//------------------------------------------------------------------------------
procedure Init;
begin
  setRandomAllMatrices;
  glIterCount:=0;
  glmsTimeLog:=0;
  Application.ProcessMessages;
  UpdateLabels;
end;

procedure freezeButtons;
begin
  Form2.Button1.Enabled:=false;
  Form2.Button2.Enabled:=false;
  Form2.Button3.Enabled:=false;
  Form2.ButtonStep.Enabled:=false;
  Form2.ButtonCombo.Enabled:=false;
end;

procedure reheatButtons;
begin
  Form2.Button1.Enabled:=true;
  Form2.Button2.Enabled:=true;
  Form2.Button3.Enabled:=true;
  Form2.ButtonStep.Enabled:=true;
  Form2.ButtonCombo.Enabled:=true;
end;

function getStraight(len:BYTE):STRING;
var str:STRING;
    i:BYTE;
begin
  str:='';
  for i := 1 to len do
    str+='─';
  Result:=str;
end;

function getHeadline(arrlen,straightlen:BYTE):STRING;
var str:STRING;
    i:BYTE;
begin
  str:='┌';
  for i:=1 to arrlen do begin
    if(i<arrlen) then
      str+=getStraight(straightlen)+'┬'
    else
      str+=getStraight(straightlen)+'┐';
  end;
  Result:=str;
end;

function getMiddle(arrlen,straightlen:BYTE):STRING;
var str:STRING;
    i:BYTE;
begin
  str:='├';
  for i:=1 to arrlen do begin
    if(i<arrlen) then
      str+=getStraight(straightlen)+'┼'
    else
      str+=getStraight(straightlen)+'┤';
  end;

  Result:=str;
end;

function getBottom(arrlen,straightlen:BYTE):STRING;
var str:STRING;
    i:BYTE;
begin
  str:='└';
  for i:=1 to arrlen do begin
    if(i<arrlen) then
      str+=getStraight(straightlen)+'┴'
    else
      str+=getStraight(straightlen)+'┘';
  end;
  Result:=str;
end;

function ArrayToStrRounded(arr:array of REAL; places:BYTE):STRING;
var str,temp:STRING;
    i:BYTE;
begin
  str:='│';
  for i := 0 to Dimensions do begin
    temp:=FloatToStrF(arr[i],ffFixed,0,places)+'│';
    if(temp[1]<>'-') then temp:=' '+temp;
    str+=temp;
  end;
  Result:=str;
end;

procedure printMatrix(items:TStrings;mat:tMatrix);
const places = 4;
var str,headline,middle,bottom:STRING;                                          //┌┐└┘─│├┤┬┴┼
    straightlen:BYTE;
    arraylen:BYTE;
    i:BYTE;
begin
  str := '';
  straightlen:=places+3;
  arraylen:=Length(mat[1]);

  headline:=getHeadline(arraylen,straightlen);
  middle:=getMiddle(arraylen,straightlen);
  bottom:=getBottom(arraylen,straightlen);

  items.Add(headline);
  for i := 1 to Length(mat) do begin
    items.Add(ArrayToStrRounded(mat[i],places));
    if(i<Length(mat)) then
      items.Add(middle);
  end;
  items.Add(bottom);
  items.Add('');
end;

{ TForm2 }

procedure TForm2.FormCreate(Sender: TObject);
begin
  Randomize;

  Form2.Width:=330;
  Form2.Height:=310;
  Form1.Width:=Screen.Width DIV 2;
  Form1.Height:=Screen.Height DIV 2;

  Form2.BringToFront;
  Form2.Position:=poDesktopCenter;
  Form1.Position:=poDesktopCenter;

  Form2.TimerCompute.Interval:=25;
  Form2.TimerCompute.Enabled:=false;

  glIsComputing:=false;
  glIsDrawing:=false;
  glIsFinished:=true;
  glIsLimited:=false;
  camYawAngle:=0;
  camPitchAngle:=0;
  camScale:=0;

  setRandomParticleArray;

  Form1.Color:=RGBtoBGR(glClearColor);
  Init;
  setFontColor;
  UpdateForm2Caption;
  Form2.ListBoxMatrix.Items.Append('bullshit');

end;

procedure TForm2.FormKeyPress(Sender: TObject; var Key: char);
begin
  if(Key='s') then
    if(Form2.Visible) then
      Form2.Hide
    else
      Form2.Show;
end;

procedure TForm2.Button1Click(Sender: TObject);
begin
  Form2.TimerCompute.Enabled:=NOT Form2.TimerCompute.Enabled;
end;

procedure TForm2.ArrowUpClick(Sender: TObject);
const delta = 0.139626;
begin
  camPitchAngle-=delta;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ArrowRightClick(Sender: TObject);
const delta = 0.139626;
begin
  camYawAngle-=delta;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ArrowLeftClick(Sender: TObject);
const delta = 0.139626;
begin
  camYawAngle+=delta;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ArrowDownClick(Sender: TObject);
const delta = 0.139626;
begin
  camPitchAngle+=delta;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.Button2Click(Sender: TObject);
var buf:BOOLEAN;
begin
  freezeButtons;
  buf := Form2.TimerCompute.Enabled;
  Form2.TimerCompute.Enabled:=false;
  Application.ProcessMessages;
  Init;
  glStepsLeft:=0;
  Application.ProcessMessages;
  Form2.TimerCompute.Enabled:=buf;
  UpdateForm2Caption;
  reheatButtons;
end;

procedure TForm2.Button3Click(Sender: TObject);
begin
  freezeButtons;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
  reheatButtons;
end;

procedure TForm2.ButtonComboClick(Sender: TObject);
begin
  freezeButtons;
  Form2.TimerCompute.Enabled:=false;
  Init;
  glStepsLeft:=Form2.SpinEditStep.Value;
  glIsLimited:=true;
  Form2.TimerCompute.Enabled:=true;
end;

procedure TForm2.ButtonMatrixClick(Sender: TObject);
begin
  if(Form2.ButtonMatrix.Caption='>') then begin
    Form2.Height:=640;
    Form2.Width:=705;
    Form2.ButtonMatrix.Caption:='<';
  end else begin
    Form2.Height:=310;
    Form2.Width:=330;
    Form2.ButtonMatrix.Caption:='>';
  end
end;

procedure TForm2.ButtonOrderMatrixClick(Sender: TObject);
begin
  Form2.ListBoxMatrix.Items.Clear;
  Form2.ListBoxMatrix.Items.Add('Matrix 1:');
  printMatrix(Form2.ListBoxMatrix.Items,glMatrix1);

  Form2.ListBoxMatrix.Items.Add('Matrix 2:');
  printMatrix(Form2.ListBoxMatrix.Items,glMatrix2);

  Form2.ListBoxMatrix.Items.Add('Matrix 3:');
  printMatrix(Form2.ListBoxMatrix.Items,glMatrix3);

  Form2.ListBoxMatrix.Items.Delete(Form2.ListBoxMatrix.Items.Count-1);

end;

procedure TForm2.ButtonRenderLoopClick(Sender: TObject);
begin
  if(Form2.TimerRender.Enabled) then begin
    Form2.TimerNew.Enabled:=false;
    Form2.TimerRender.Enabled:=false;
  end else begin
    Form2.TimerNew.Enabled:=true;
    Form2.TimerRender.Enabled:=true;
  end;
end;

procedure TForm2.ButtonResetClick(Sender: TObject);
begin
  camPitchAngle:=0;
  camYawAngle:=0;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ButtonResetHorizontalClick(Sender: TObject);
begin
  camYawAngle:=0;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ButtonResetVerticalClick(Sender: TObject);
begin
  camPitchAngle:=0;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ButtonStepClick(Sender: TObject);
begin
  freezeButtons;
  Form2.TimerCompute.Enabled:=false;
  glStepsLeft:=Form2.SpinEditStep.Value;
  glIsLimited:=true;
  Form2.TimerCompute.Enabled:=true;
end;

procedure TForm2.ButtonZoomInClick(Sender: TObject);
const delta = 0.25;
begin
  camScale+=delta;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ButtonZoomOutClick(Sender: TObject);
const delta = 0.25;
begin
  camScale-=delta;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.ButtonZoomResetClick(Sender: TObject);
begin
  camScale:=0;
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
end;

procedure TForm2.FormResize(Sender: TObject);
begin
  UpdateLabels;
  setFontColor;
  //Form2.ButtonCombo.Top:=Form2.Height-10-Form2.ButtonCombo.Height;
  //Form2.SpinEditStep.Top:=Form2.ButtonCombo.Top+(Form2.ButtonCombo.Height-Form2.SpinEditStep.Height) DIV 2;
  ////Form2.ButtonCombo.Left:=Form2.Width-10-Form2.ButtonCombo.Width;
  //Form2.ButtonStep.Top:=Form2.Height-20-Form2.ButtonCombo.Height-Form2.ButtonStep.Height;

end;

procedure TForm2.PaintBoxPaint(Sender: TObject);
begin
  //Form2.PaintBox.Canvas.Brush.Color:=clBlack;
  //Form2.PaintBox.Canvas.Rectangle(0,0,200,200);
  //Form2.PaintBox.Canvas.Brush.Color:=clFuchsia;
  //Form2.PaintBox.Canvas.Ellipse(0,0,90,90);
end;

procedure TForm2.TimerComputeStartTimer(Sender: TObject);
begin
  glIsComputing:=true;
  Form2.Button1.Caption:='Turn Off';
  UpdateForm2Caption;
end;

procedure TForm2.TimerComputeStopTimer(Sender: TObject);
begin
  glIsComputing:=false;
  Form2.Button1.Caption:='Turn On';
  UpdateForm2Caption;
end;

procedure TForm2.TimerComputeTimer(Sender: TObject);
begin
  if (glStepsLeft>0) OR NOT glIsLimited then begin
    TransformArray(globalArray);
    UpdateLabels;
  end
  else begin
    Form2.TimerCompute.Enabled:=false;
    glStepsLeft:=0;
    glIsLimited:=false;
    glIsDrawing:=true;
    UpdateForm2Caption;
    DrawArray;
    glIsDrawing:=false;
    UpdateForm2Caption;
    UpdateLabels;
    reheatButtons;
  end;
end;

procedure TForm2.TimerNewTimer(Sender: TObject);
begin
  Init;
end;

procedure TForm2.TimerRenderTimer(Sender: TObject);
var time:QWord;
begin
  time:=GetTickCount64;
  TransformArray(globalArray);
  glIsDrawing:=true;
  UpdateForm2Caption;
  DrawArray;
  glIsDrawing:=false;
  UpdateForm2Caption;
  UpdateLabels;
  time:=GetTickCount64-time;
  if(time<33) then time:=40;
  if(time>500) then time:=250;
  Form2.TimerRender.Interval:=time;
end;

end.

