unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Menus, ComCtrls, Math, MTProcs;

type

  { TForm1 }

  TForm1 = class(TForm)
    PaintBox: TPaintBox;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormResize(Sender: TObject);
    procedure PaintBoxPaint(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

procedure RenderParticles;

implementation

{$R *.lfm}
uses Unit2;

type tPixelArray = array of LONGWORD;

var DisplayBmp: TBitmap;
    PixelBuffer:tPixelArray;
    BWidth, BHeight:INTEGER;

function scaling(s:REAL):REAL;
begin
  if(s>=0) then
    Result:=s+1
  else
    Result:=1/(1-s);
end;

function CameraRotation(p:tVector):tVector;
var i:BYTE;
    temp1,temp2:tVector;
begin
  for i := 1 to Dimensions+1 do begin
    temp1[i]:=p[i]*scaling(camScale);
    temp2[i]:=p[i]*scaling(camScale);
  end;
  if(Dimensions>2) then begin
    //pitch (X axis rotation)           //scale
    temp1[1]:=p[1]*scaling(camScale);
    temp1[2]:=cos(camPitchAngle)*p[2]*scaling(camScale)-sin(camPitchAngle)*p[3]*scaling(camScale);
    temp1[3]:=sin(camPitchAngle)*p[2]*scaling(camScale)+cos(camPitchAngle)*p[3]*scaling(camScale);
    temp1[Dimensions+1]:=1;

    //yaw (Y axis rotation)
    temp2[1]:=cos(camYawAngle)*temp1[1]+sin(camYawAngle)*temp1[3];
    temp2[2]:=temp1[2];
    temp2[3]:=-sin(camYawAngle)*temp1[1]+cos(camYawAngle)*temp1[3];
    temp2[Dimensions+1]:=1;
  end;
  Result:=temp2;
end;

//procedure DrawParticle(index: PtrInt; data: Pointer; item: TMultiThreadProcItem);
//var P: ^tParticle;
//    W, H: Integer;
//begin
//  P := @globalArray[Index];
//  W := Buffer.Width;
//  H := Buffer.Height;
//  { Update particle position. }
//  P^.pos[1] := P^.pos[1] + P^.pos[1];
//  P^.pos[2] := P^.pos[2] + P^.pos[2];
//end;

procedure ClearPixels;
var PixelCount: Integer;
begin
  PixelCount := Length(PixelBuffer);
  if PixelCount > 0 then
    FillDWord(PixelBuffer[0], PixelCount, glClearColor);
end;

procedure RenderParticle(Index: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
var p:^tParticle;
    rotated:tVector;
    x, y, smallest:INTEGER;
begin
  p := @globalArray[Index];
  rotated := CameraRotation(p^.pos);
  smallest := min(BWidth,BHeight);
  x := round(BWidth/2+smallest*rotated[1]/2);
  y := round(BHeight/2-smallest*rotated[2]/2);
  if not ((x<0) OR (x>BWidth-1) OR (y<0) OR (y>BHeight-1)) then
    PixelBuffer[y*BWidth+x] := p^.color;
end;

procedure RenderParticles;
var y, rowBytes: Integer;
    src, dst: Pointer;
begin
  ClearPixels;

  ProcThreadPool.DoParallel(@RenderParticle, 1, ParticleNumber, nil);

  DisplayBmp.BeginUpdate(False);
  RowBytes := BWidth * SizeOf(TColor);
  try
    for y := 0 to BHeight - 1 do begin
      src := @PixelBuffer[y * BWidth];
      dst := DisplayBmp.ScanLine[y];
      Move(src^, dst^, RowBytes);
    end;
  finally
    DisplayBmp.EndUpdate(False);
  end;

  Form1.PaintBox.Invalidate;
end;

procedure CreateBitmapBuffer(AWidth, AHeight: Integer);
begin
  if (AWidth < 1) then
    BWidth := 1
  else
    BWidth := AWidth;

  if (AHeight < 1) then
    BHeight := 1
  else
    BHeight := AHeight;

  SetLength(PixelBuffer, BWidth * BHeight);

  DisplayBmp := TBitmap.Create;
  DisplayBmp.PixelFormat := pf32bit;
  DisplayBmp.SetSize(BWidth, BHeight);
end;

procedure DestroyBitmapBuffer;
begin
  FreeAndNil(DisplayBmp);
  SetLength(PixelBuffer, 1);

  BWidth := 0;
  BHeight := 0;
end;

{ TForm1 }

procedure TForm1.FormResize(Sender: TObject);
var neww,newh:INTEGER;
begin
  Form1.PaintBox.Left:=0;
  Form1.PaintBox.Top:=0;
  Form1.PaintBox.Width:=Form1.Width;
  Form1.PaintBox.Height:=Form1.Height;
  neww:=Form1.PaintBox.Width;
  newh:=Form1.PaintBox.Height;
  if(neww<1) then neww:=1;
  if(newh<1) then newh:=1;
  if(neww=BWidth)AND(newh=BHeight) then Exit;
  DestroyBitmapBuffer;
  Application.ProcessMessages;
  CreateBitmapBuffer(neww,newh);
end;

procedure TForm1.PaintBoxPaint(Sender: TObject);
begin
  if Assigned(DisplayBmp) then
    Form1.PaintBox.Canvas.Draw(0, 0, DisplayBmp);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CreateBitmapBuffer(1,1);
end;

procedure TForm1.FormKeyPress(Sender: TObject; var Key: char);
begin
  if(Key='s') then
    if(Form2.Visible) then
      Form2.Hide
    else
      Form2.Show;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Form2.TimerRender.Enabled:=false;
  DisplayBmp.Free;
end;

end.

