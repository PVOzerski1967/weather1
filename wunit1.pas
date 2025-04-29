unit wunit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    BreakButton: TButton;
    DeltaEdit: TEdit;
    Elevation: TCheckBox;
    CopyButton: TButton;
    Label1: TLabel;
    Precipitation: TCheckBox;
    BioClim: TCheckBox;
    RadioGroup1: TRadioGroup;
    Temperature: TCheckBox;
    PasteButton: TButton;
    GoButton: TButton;
    Memo1: TMemo;
    procedure BreakButtonClick(Sender: TObject);
    procedure CopyButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    procedure PasteButtonClick(Sender: TObject);
    procedure RadioGroup1SelectionChanged(Sender: TObject);
  private
    CmdToStop: boolean;
    TwoDigits: boolean;
    procedure makemounth(param: string; m: integer);
    procedure RedefDelta;
  public

  end;

var
  Form1: TForm1;

implementation
uses
  clipbrd, dos;
{$R *.lfm}

{ TForm1 }
var
  Delta: integer = 10000;

procedure TForm1.RedefDelta;
var
  x: real;
  s: string;
  i: integer;
begin
  s := DeltaEdit.Text;
  for i := 1 to length(s) do
    if s[i] = ',' then
      s[i] := '.';
  val(s, x, i);
  if x > 0 then
    Delta := round(x);
  str(Delta, s);
  DeltaEdit.Text := s;
end;

procedure TForm1.GoButtonClick(Sender: TObject);
var
  i: integer;
begin
  RedefDelta;
  CmdToStop := false;
  while Memo1.Lines.Count > 0 do
    begin
      if Memo1.Lines[Memo1.Lines.Count - 1] = '' then
        Memo1.Lines.Delete(Memo1.Lines.Count - 1)
      else
        break;
    end;
  if (Elevation.Enabled) and (Elevation.Checked) then
    makemounth('wc2.1_30s_elev.tif', -1);
  TwoDigits := true;
  if Temperature.Checked then
    for i := 1 to 12 do
      begin
        if CmdToStop then
          break;
        case RadioGroup1.ItemIndex of
          0: makemounth('wc2.1_30s_tavg_$0MONTH.tif', i);
          1: makemounth('CHELSA_temp10_$0MONTH_1979-2013_V1.2_land.tif', i);
          2: makemounth('CHELSA_tas_$0MONTH_1981-2010_V.2.1.tif', i);
        end;
      end;
  if Precipitation.Checked then
    for i := 1 to 12 do
      begin
        if CmdToStop then
          break;
        case RadioGroup1.ItemIndex of
          0: makemounth('wc2.1_30s_prec_$0MONTH.tif', i);
          1: makemounth('CHELSA_prec_$0MONTH_V1.2_land.tif', i);
          2: makemounth('CHELSA_pr_$0MONTH_1981-2010_V.2.1.tif', i);
        end;
      end;
  TwoDigits := false;
  if BioClim.Checked then
    for i := 1 to 19 do
      begin
        if CmdToStop then
          break;
        case RadioGroup1.ItemIndex of
          0: makemounth('wc2.1_30s_bio_$1MONTH.tif', i);
          1: makemounth('CHELSA_bio10_$0MONTH.tif', i);
          2: makemounth('CHELSA_bio$1MONTH_1981-2010_V.2.1.tif', i);
        end;
      end;
end;

procedure TForm1.BreakButtonClick(Sender: TObject);
begin
  CmdToStop := true;
end;

procedure TForm1.CopyButtonClick(Sender: TObject);
begin
  Clipboard.AsText := Memo1.Text;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  RedefDelta;
end;

procedure TForm1.PasteButtonClick(Sender: TObject);
var
  s: string;
  pdot, pcomma, i, L: integer;
begin
  if Clipboard.HasFormat(cf_Text) then
    begin
      s := Clipboard.AsText;
      pdot := pos('.', s);
      pcomma := pos(',', s);
      L := length(s);
      if (pdot > 0) and (pcomma > 0) then
        if pdot < L then
          if s[pdot + 1] in ['0'..'9'] then
            begin
              for i := 1 to L do
                if s[i] = ',' then
                  s[i] := #9;
              for i := 1 to L do
                if s[i] = '.' then
                  s[i] := ',';
            end;
      Memo1.Text := s;
    end;
end;

procedure TForm1.RadioGroup1SelectionChanged(Sender: TObject);
begin
  Elevation.Enabled := RadioGroup1.ItemIndex = 0;
end;

procedure TForm1.makemounth(param: string; m: integer);
  procedure GetLatLon(idx: integer; var Lat, Lon: string);
  var
    s: string;
    ss: array[0..1] of string;
    i, j: integer;
  begin
    s := trim(Memo1.Lines[idx]);
    ss[0] := '';
    ss[1] := '';
    j := 0;
    for i := 1 to length(s) do
      if s[i] = #9 then
        begin
          inc(j);
          if j > 1 then
            break;
        end
      else if s[i] = ' ' then
      else
        begin
          if s[i] = ',' then
            ss[j] := ss[j] + '.'
          else
            ss[j] := ss[j] + s[i];
        end;
     Lat := ss[0];
     Lon := ss[1];
  end;
  function Stri(x: real): string;
  var
    i: integer;
  begin
    Str(x:0:10, Result);
    repeat
      if Result = '' then
        break;
      if (Result[length(Result)] = '0') and (pos('E', UpperCase(Result)) = 0) and (pos('.', Result) > 0) then
        SetLength(Result, length(Result) - 1)
      else
        break;
    until false;
    for i := 1 to length(Result) do
      if Result[i] = '.' then
        begin
          Result[i] := ',';
          break;
        end;
    if Result <> '' then
      if Result[length(Result)] = ',' then
        Result := Result + '0';
  end;

type
  TStringArray = array of string;
  TRealArray = array of real;

  function CallPython(Lat, Lon: TStringArray): TRealArray;
  const
    Template_WorldClim: array[0..12] of shortstring =(
      'import rasterio',
      'dat = rasterio.open(r"$PARAM")',
      'z = dat.read()[0]',
      'dat.crs',
      'dat.bounds',
      'def getval(lon, lat):',
      '    idx = dat.index(lon, lat)',
      '    return dat.xy(*idx), z[idx]',
      'file = open("Coord_temp.txt", "w")',
      'dt2 = getval($LON, $LAT)',
      'file.write(str(dt2))',
      'file.write("\n")',
      'file.close()'
    );
  var
    t: text;
    i, j: integer;
    s: string;
    function Subst(s: string; Param: string; m: integer): string;
      function two_digit(mm: integer): string;
      begin
        str(mm, Result);
        if length(Result) = 1 then
          Result := '0' + Result;
      end;
    begin
      if pos('$0MONTH', param) > 0 then
        param := StringReplace(param, '$0MONTH', two_digit(m), [])
      else if pos('$1MONTH', param) > 0 then
        param := StringReplace(param, '$1MONTH', intToStr(m), []);
      Result := StringReplace(s, '$PARAM', param, []);
    end;
    function Subst2(s: string; idx: integer): string;
      function ToStr(X: String): string;
      var
        i: integer;
      begin
        for i := 1 to length(X) do
          if X[i] = ',' then
            begin
              X[i] := '.';
              break;
            end;
        Result := X;
      end;
    begin
      s := StringReplace(s, '$LAT', ToStr(Lat[idx]), []);
      Result := StringReplace(s, '$LON', ToStr(Lon[idx]), []);
    end;
  const
    Script = 'Coord_temp.py';
  begin
    assignfile(t, Script);
    rewrite(t);
    writeln(t, Template_WorldClim[0]);
    writeln(t, Subst(Template_WorldClim[1], Param, m));
    for i := 2 to 8 do
      writeln(t, Template_WorldClim[i]);
    for i := 0 to high(Lat) do
      begin
        writeln(t, Subst2(Template_WorldClim[9], i));
        writeln(t, Template_WorldClim[10]);
        if i < high(Lat) then
          writeln(t, Template_WorldClim[11]);
      end;
    writeln(t, Template_WorldClim[12]);
    closefile(t);
    Application.ProcessMessages;
    Exec('/usr/bin/python3', Script);
    Application.ProcessMessages;
    assignfile(t, 'Coord_temp.txt');
    reset(t);
    Result := nil;
    SetLength(Result, length(Lat));
    for j := 0 to high(Lat) do
      begin
        readln(t, s);
        s := StringReplace(s, ')', '', [rfReplaceAll]);
        for i := length(s) downto 1 do
          if s[i] = ' ' then
            begin
              s := copy(s, i + 1, length(s));
              break;
            end;
        val(s, Result[j], i);
      end;
    closefile(t);
  end;


var
  i: integer;
  _from, _to: integer;
  ro: boolean;
  Lat, Lon: TStringArray;
  value: TRealArray;
begin
  ro := Memo1.ReadOnly;
  Memo1.ReadOnly := true;
  _from := 0;
  Lat := nil;
  Lon := nil;
  repeat
    if CmdToStop then
      break;
    _to := _from + Delta;
    if _to >= Memo1.Lines.Count then
      _to := Memo1.Lines.Count - 1;
    SetLength(Lat, _to - _from + 1);
    SetLength(Lon, length(Lat));
    for i := 0 to high(Lat) do
      GetLatLon(_from + i, Lat[i], Lon[i]);
    Value := CallPython(Lat, Lon);
    for i := 0 to high(Lat) do
      Memo1.lines[_from + i] := Memo1.lines[_from + i] + #9 + Stri(Value[i]);
    _from := _to + 1;
  until _from >= Memo1.Lines.Count;

  Memo1.ReadOnly := ro;
end;

end.

