program netbios_cn_s;

uses DOS, CRT;

const
  NCBRESET = $32;
  NCBADDGRNAME = $36;
  NCBDELNAME = $31;
  NCBLISTEN = $11;
  NCBHANGUP = $12;
  NCBRECV = $15;
  NRC_GOODRET = 0;

type
  TName16 = array[1..16] of Char;
  TBuf = array[0..255] of Char;
  TNCB = record
    ncb_command: Byte;
    ncb_retcode: Byte;
    ncb_lsn: Byte;
    ncb_num: Byte;
    ncb_buf_ofs: Word;
    ncb_buf_seg: Word;
    ncb_length: Word;
    ncb_callname: TName16;
    ncb_name: TName16;
    ncb_rto: Byte;
    ncb_sto: Byte;
    ncb_post_ofs: Word;
    ncb_post_seg: Word;
    ncb_lana_num: Byte;
    ncb_cmd_cplt: Byte;
    ncb_reserve: array[1..14] of Char;
  end;

var
  N: TNCB;
  Buf: TBuf;
  S: string;

procedure SetName16(var A: TName16; const S: string);
var
  L: Integer;
begin
  FillChar(A, 16, 32);
  L := Length(S);
  if L > 16 then L := 16;
  if L > 0 then Move(S[1], A, L);
end;

procedure SetNcbBuf(var N: TNCB; var Buf; Len: Word);
begin
  N.ncb_buf_seg := Seg(Buf);
  N.ncb_buf_ofs := Ofs(Buf);
  N.ncb_length := Len;
end;

function NetbiosCmd(var N: TNCB): Byte;
var
  R: Registers;
begin
  N.ncb_cmd_cplt := $FF;
  R.ES := Seg(N);
  R.BX := Ofs(N);
  Intr($5C, R);
  while N.ncb_cmd_cplt = $FF do
  begin
  end;
  NetbiosCmd := N.ncb_cmd_cplt;
end;

function BufToStr(const B: TBuf): string;
var
  i: Integer;
  R: string;
begin
  R := '';
  i := 0;
  while (i < 256) and (B[i] <> #0) do
  begin
    R := R + B[i];
    Inc(i);
  end;
  BufToStr := R;
end;

begin
  ClrScr;
  WriteLn('Сервер Netbios-каналы');
  FillChar(N, SizeOf(N), 0);
  N.ncb_lana_num := 0;
  WriteLn('Инициализация адаптера');
  N.ncb_command := NCBRESET;
  if NetbiosCmd(N) <> NRC_GOODRET then
  begin
    WriteLn('Ошибка: ', N.ncb_cmd_cplt);
    Halt(1);
  end;
  SetName16(N.ncb_name, 'NetbiosChannel');
  WriteLn('Добавление имени');
  N.ncb_command := NCBADDGRNAME;
  if NetbiosCmd(N) <> NRC_GOODRET then
  begin
    WriteLn('Ошибка: ', N.ncb_cmd_cplt);
    Halt(2);
  end;
  SetName16(N.ncb_callname, '*');
  WriteLn('Ожидание подключения шлюза');
  N.ncb_command := NCBLISTEN;
  if NetbiosCmd(N) <> NRC_GOODRET then
  begin
    WriteLn('Ошибка: ', N.ncb_cmd_cplt);
    Halt(3);
  end;
  WriteLn('Ожидание сообщений');
  repeat
    N.ncb_command := NCBRECV;
    SetNcbBuf(N, Buf, 256);
    if NetbiosCmd(N) <> NRC_GOODRET then
    begin
      WriteLn('Соединение потеряно');
      Halt(4);
    end;
    S := BufToStr(Buf);
    WriteLn('Получено: ', S);
  until S = 'exit';
  N.ncb_command := NCBHANGUP;
  NetbiosCmd(N);
  N.ncb_command := NCBDELNAME;
  NetbiosCmd(N);
end.
