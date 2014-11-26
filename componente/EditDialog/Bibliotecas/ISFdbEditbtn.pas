{************************************************************************}
{ TISFdbEditBtn component                                                }
{ for Delphi 5.0,6.0,7.0,2005,2006 & C++Builder 5.0,6.0,2006             }
{ version 1.3                                                            }
{                                                                        }
{ written by TMS Software                                                }
{            copyright � 2000 - 2006                                     }
{            Email : info@tmssoftware.com                                }
{            Web : http://www.tmssoftware.com                            }
{                                                                        }
{ The source code is given as is. The author is not responsible          }
{ for any possible damage done due to the use of this code.              }
{ The component can be freely used in any application. The complete      }
{ source code remains property of the author and may not be distributed, }
{ published, given or sold in any form as such. No parts of the source   }
{ code can be included in any other component or application without     }
{ written authorization of the author.                                   }
{************************************************************************}

unit ISFdbEditbtn;

//{$I TMSDEFS.INC}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ISFEdit, ISFEditbtn, DB, dbctrls;

type
  TISFdbEditBtn = class(TISFEditBtn)
  private
    { Private declarations }
    FClearOnInsert: Boolean;
    FDataLink: TFieldDataLink;
    FCanvas: TControlCanvas;
    FOldState: TDataSetState;
    FIsEditing: Boolean;    
    function GetDataField: string;
    function GetDataSource: TDataSource;
    function GetReadOnly: Boolean;
    procedure SetDataField(const Value: string);
    procedure SetDataSource(const Value: TDataSource);
    procedure SetReadOnly(Value: Boolean);
    procedure DataUpdate(Sender: TObject);
    procedure DataChange(Sender: TObject);
    procedure ActiveChange(Sender: TObject);
    procedure WMChar(var Message: TWMKeyDown); message WM_CHAR;
    procedure WMCut(var Message: TMessage); message WM_CUT;
    procedure WMPaste(var Message: TMessage); message WM_PASTE;
    procedure WMUndo(var Message: TMessage); message WM_UNDO;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure CMExit(var Message: TWMNoParams); message CM_EXIT;
    procedure CMEnter(var Message: TCMEnter); message CM_ENTER;
    {$IFNDEF TMSDOTNET}
    procedure CMGetDataLink(var Message: TMessage); message CM_GETDATALINK;
    {$ENDIF}
    procedure ResetMaxLength;
    function GetTextMargins: TPoint;
  protected
    { Protected declarations }
    procedure Change; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure Loaded; override;
    function EditCanModify: Boolean; virtual;    
  public
    { Public declarations }
    constructor Create(aOwner:TComponent); override;
    destructor Destroy; override;
    {$IFDEF DELPHI4_LVL}
    function ExecuteAction(Action: TBasicAction): Boolean; override;
    function UpdateAction(Action: TBasicAction): Boolean; override;
    {$ENDIF}
  published
    { Published declarations }
    property ClearOnInsert: Boolean read FClearOnInsert write FClearOnInsert default False;    
    property DataField: string read GetDataField write SetDataField;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly default False;
  end;



implementation


procedure TISFdbEditBtn.ResetMaxLength;
var
  F: TField;
begin
  if (MaxLength > 0) and Assigned(DataSource) and Assigned(DataSource.DataSet) then
  begin
    F := DataSource.DataSet.FindField(DataField);
    if Assigned(F) and (F.DataType in [ftString {$IFDEF DELPHI4_LVL}, ftWideString {$ENDIF} ]) and (F.Size = MaxLength) then
      MaxLength := 0;
  end;
end;

procedure TISFdbEditBtn.Change;
begin
  FDataLink.Modified;
  inherited;
end;

{$IFNDEF TMSDOTNET}
procedure TISFdbEditBtn.CMGetDataLink(var Message: TMessage);
begin
  Message.Result := Integer(FDataLink);
end;
{$ENDIF}

procedure TISFdbEditBtn.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  if (csDestroying in ComponentState) then
    Exit;
  
  if (Operation = opRemove) and (FDataLink <> nil) and
    (AComponent = DataSource) then DataSource := nil;
end;

procedure TISFdbEditBtn.CMExit(var Message: TWMNoParams);
begin
 if not FDataLink.ReadOnly then
  begin
   try
      FDataLink.UpdateRecord;                          { tell data link to update database }
   except
      on Exception do SetFocus;                      { if it failed, don't let focus leave }
   end;
  end;
  inherited;
end;

procedure TISFdbEditBtn.CMEnter(var Message: TWMNoParams);
begin
 inherited;
 if FDataLink.CanModify then inherited ReadOnly := False;
end;

constructor TISFdbEditBtn.Create(aOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := DataChange;
  FDataLink.OnUpdateData := DataUpdate;
  FDataLink.OnActiveChange := ActiveChange;  
  ControlStyle := ControlStyle + [csReplicatable];
end;

procedure TISFdbEditBtn.DataChange(Sender: TObject);
begin
Try
  if not Assigned(FDataLink.DataSet) then
    Exit;

  if FIsEditing then
    Exit;

  if Assigned(FDataLink.Field) and
     not (FClearOnInsert and (FDataLink.DataSet.State = dsInsert) and
     (FOldState <> dsInsert))  then
  begin
    case self.EditType of
    etString,etAlphaNumeric,etLowerCase,etUpperCase,etMixedCase:
      begin
        if not (csDesigning in ComponentState) then
        begin
          Try
             if (FDataLink.Field.DataType in [ftString, ftWideString]) and (MaxLength = 0) then
                MaxLength := FDataLink.Field.Size;
             self.Text := FDataLink.Field.Text;
          except
          End;
        end;
      end;
    etFloat,etMoney:
      begin
        if (FDataLink.Field.AsString = '') then
          self.FloatValue := 0.0
        else
          self.FloatValue := FDataLink.Field.AsFloat;
      end;
    etNumeric:
      begin
        if (FDataLink.Field.AsString = '') then
          self.IntValue := 0
        else
          self.IntValue := FDataLink.Field.AsInteger;
      end;
    else
      self.Text := FDataLink.Field.AsString;
    end;
    Modified := False;
  end;

  if (FDataLink.DataSet.State = dsInsert) and FClearOnInsert
    and (FOldState <> dsInsert) then
  begin
    if (self.EditType in [etFloat,etMoney,etNumeric]) then
      self.Text := '0'
    else
      self.Text := '';
  end;
except
End;

  FOldState := FDataLink.DataSet.State;
end;

procedure TISFdbEditBtn.DataUpdate(Sender: TObject);
begin
try
  if Assigned(FDataLink.Field) and
     not (FClearOnInsert and (FDataLink.DataSet.State = dsInsert)) then
  begin
    case self.EditType of
    etMoney,etFloat:
      begin
        FDataLink.Field.AsFloat := self.FloatValue
      end;
    etNumeric:
      begin
        FDataLink.Field.AsInteger := self.IntValue
      end;
    else
      begin
        FDataLink.Field.AsString := self.Text;
      end;
    end;
  end;
except
end;
end;

destructor TISFdbEditBtn.Destroy;
begin
  FDataLink.Free;      
  inherited Destroy;
end;


function TISFdbEditBtn.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

function TISFdbEditBtn.GetDataSource: TDataSource;
begin
 Result := FDataLink.DataSource;
end;

function TISFdbEditBtn.GetReadOnly: Boolean;
begin
  Result := FDataLink.ReadOnly;
end;

procedure TISFdbEditBtn.SetDataField(const Value: string);
begin
  if not (csDesigning in ComponentState) then ResetMaxLength;
  FDataLink.FieldName := Value;
end;

procedure TISFdbEditBtn.SetDataSource(const Value: TDataSource);
begin
 FDataLink.DataSource := Value;
end;

procedure TISFdbEditBtn.SetReadOnly(Value: Boolean);
begin
  FDataLink.ReadOnly := Value;
end;

procedure TISFdbEditBtn.WMCut(var Message: TMessage);
begin
  FDataLink.Edit;
  inherited;
end;

procedure TISFdbEditBtn.WMPaste(var Message: TMessage);
begin
  if not FDataLink.Readonly then
   begin
    FDataLink.Edit;
    inherited;
   end;
end;

procedure TISFdbEditBtn.WMUndo(var Message: TMessage);
begin
  FDataLink.Edit;
  inherited;
end;

procedure TISFdbEditBtn.KeyDown(var Key: Word; Shift: TShiftState);
begin

  if (Key = VK_DELETE) or ((Key = VK_INSERT) and (ssShift in Shift)) then
  begin
    if not EditCanModify then
    begin
      key := 0;
      Exit;
    end;
  end;

  if FDataLink.ReadOnly and (key = VK_DELETE) then
    Key := 0;

  inherited KeyDown(Key, Shift);

  if (Key = VK_DELETE) or ((Key = VK_INSERT) and (ssShift in Shift)) then
    FDataLink.Edit;
    
end;

procedure TISFdbEditBtn.KeyPress(var Key: Char);
begin
  if not ((Key = #13) and ReturnIsTab) then

    //if not EditCanMOdify then
    //  Exit;


  inherited KeyPress(Key);

  if (Key in [#32..#255]) and (FDataLink.Field <> nil) and (Key <> '.') and   
    not FDataLink.Field.IsValidChar(Key) or (FDataLink.ReadOnly) then
  begin
    MessageBeep(0);
    Key := #0;
  end;

  case Key of
    ^H, ^V, ^X, #32..#255:
      FDataLink.Edit;
    #27:
      begin
        FDataLink.Reset;
        //SelectAll;
        Key := #0;
      end;
  end;
end;

procedure TISFdbEditBtn.Loaded;
begin
  inherited Loaded;
  ResetMaxLength;
end;


procedure TISFdbEditBtn.WMPaint(var Message: TWMPaint);
var
  Left: Integer;
  Margins: TPoint;
  R: TRect;
  DC: HDC;
  PS: TPaintStruct;
  S: string;
  AAlignment: TAlignment;

begin

 if  not (csPaintCopy in ControlState) then inherited
 else
  begin
  if FCanvas = nil then
  begin
    FCanvas := TControlCanvas.Create;
    FCanvas.Control := Self;
  end;

  if EditType in [etFloat,etNumeric,etMoney,etHex] then
    AAlignment := taRightJustify
  else
    AAlignment := taLeftJustify;

  DC := Message.DC;
  if DC = 0 then DC := BeginPaint(Handle, PS);
  FCanvas.Handle := DC;
  try
    FCanvas.Font := Font;
    with FCanvas do
    begin
      R := ClientRect;
      if not (NewStyleControls and Ctl3D) and (BorderStyle = bsSingle) then
      begin
        Brush.Color := clWindowFrame;
        FrameRect(R);
        InflateRect(R, -1, -1);
      end;
      Brush.Color := Color;
      if not Enabled then
        Font.Color := clGrayText;
      if (csPaintCopy in ControlState) and (FDataLink.Field <> nil) then
      begin
        S := FDataLink.Field.DisplayText;
        case CharCase of
          ecUpperCase: S := AnsiUpperCase(S);
          ecLowerCase: S := AnsiLowerCase(S);
        end;
      end else
        S := Text;
      {$IFNDEF TMSDOTNET}
      if PasswordChar <> #0 then FillChar(S[1], Length(S), PasswordChar);
      {$ENDIF}
      {$IFDEF TMSDOTNET}
      if PasswordChar <> #0 then S := PasswordChar;
      {$ENDIF}

      Margins := GetTextMargins;
      case AAlignment of
        taLeftJustify: Left := Margins.X;
        taRightJustify: Left := ClientWidth - TextWidth(S) - Margins.X - 1;
      else
        Left := (ClientWidth - TextWidth(S)) div 2;
      end;
      {$IFDEF DELPHI4_LVL}
      if SysLocale.MiddleEast then UpdateTextFlags;
      {$ENDIF}
      TextRect(R, Left, Margins.Y, S);
    end;
  finally
    FCanvas.Handle := 0;
    if Message.DC = 0 then EndPaint(Handle, PS);
  end;

  end;
end;

function TISFdbEditBtn.GetTextMargins: TPoint;
var
  DC: HDC;
  SaveFont: HFont;
  I: Integer;
  SysMetrics, Metrics: TTextMetric;
begin
  if NewStyleControls then
  begin
    if BorderStyle = bsNone then I := 0 else
      if Ctl3D then I := 1 else I := 2;
    Result.X := SendMessage(Handle, EM_GETMARGINS, 0, 0) and $0000FFFF + I;
    Result.Y := I;
  end else
  begin
    if BorderStyle = bsNone then I := 0 else
    begin
      DC := GetDC(0);
      GetTextMetrics(DC, SysMetrics);
      SaveFont := SelectObject(DC, Font.Handle);
      GetTextMetrics(DC, Metrics);
      SelectObject(DC, SaveFont);
      ReleaseDC(0, DC);
      I := SysMetrics.tmHeight;
      if I > Metrics.tmHeight then I := Metrics.tmHeight;
      I := I div 4;
    end;
    Result.X := I;
    Result.Y := I;
  end;
end;


{$IFDEF DELPHI4_LVL}

function TISFdbEditBtn.ExecuteAction(Action: TBasicAction): Boolean;
begin
  Result := inherited ExecuteAction(Action) or (FDataLink <> nil) and
    FDataLink.ExecuteAction(Action);
end;

function TISFdbEditBtn.UpdateAction(Action: TBasicAction): Boolean;
begin
  Result := inherited UpdateAction(Action) or (FDataLink <> nil) and
    FDataLink.UpdateAction(Action);
end;

{$ENDIF}



procedure TISFdbEditBtn.ActiveChange(Sender: TObject);
begin
try
  if Assigned(FDataLink) then
  begin
    if Assigned(FDataLink.DataSet) then
    begin
      if not FDataLink.DataSet.Active then
        Text := '';
    end
    else
    begin
      Text := '';
    end;
  end;
except
end;
end;

procedure TISFdbEditBtn.WMChar(var Message: TWMKeyDown);
begin
  if (Message.CharCode in [32..255]) and (FDataLink.Field <> nil) and (Message.charcode <> Ord('.'))
     and (Message.charcode <> Ord(',')) and (not FDataLink.Field.IsValidChar(Chr(Message.CharCode))) then
  begin
    Message.Result := 1;
    Message.CharCode := 0;
  end;

  if not ((Message.CharCode = 13) and ReturnIsTab) then
  begin
    FIsEditing := true;
    if not EditCanModify then
    begin
      Message.Result := 1;
      Message.CharCode := 0;
    end;
    FIsEditing := False;
  end;
  inherited;

end;

function TISFdbEditBtn.EditCanModify: Boolean;
begin
  Result := FDataLink.Edit;
end;

end.
