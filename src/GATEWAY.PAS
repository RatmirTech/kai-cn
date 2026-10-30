program gateway;

uses DOS, CRT;

const
  NCBRESET = $32;
  NCBADDNAME = $30;
  NCBADDGRNAME = $36;
  NCBDELNAME = $31;
  NCBCALL = $10;
  NCBLISTEN = $11;
  NCBHANGUP = $12;
  NCBSEND = $14;
  NCBRECV = $15;
  NCBDGSEND = $20;
  NCBDGRECV = $21;
  NRC_GOODRET = 0;
  SPX_SOCKET = $1000;

type
  TName16 = array[1..16] of Char;
  TBuf = array[0..255] of Char;
  TAddress = array[1..6] of Byte;
  TNetNum = array[1..4] of Byte;
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
  TIPXRegs = record
    Ax: Word;
    Bx: Word;
    Cx: Word;
    Dx: Word;
    Si: Word;
    Di: Word;
    Es: Word;
  end;
  TPacket = record
    CheckSum: Word;
    Length: Word;
    TransportControl: Byte;
    PacketType: Byte;
    DestNetwork: TNetNum;
    DestNode: TAddress;
    DestSocket: Word;
    SourceNetwork: TNetNum;
    SourceNode: TAddress;
    SourceSocket: Word;
    ConnControl: Byte;
    DataStreamType: Byte;
    SourceConnID: Word;
    DestConnID: Word;
    SeqNumber: Word;
    AckNumber: Word;
    AllocNumber: Word;
    Data: string[255];
  end;
  TECB = record
    Link: array[1..2] of Word;
    ESRAddrOfs: Word;
    ESRAddrSeg: Word;
    InUse: Byte;
    CCode: Byte;
    Socket: Word;
    IPXWork: array[1..2] of Word;
    DrvWork: array[1..6] of Word;
    ImmAddr: TAddress;
    FragCnt: Word;
    Addr1Ofs: Word;
    Addr1Seg: Word;
    Size1: Word;
    Addr2Ofs: Word;
    Addr2Seg: Word;
    Size2: Word;
  end;

var
  regis: Registers;
  dg, cn: TNCB;
  mecb, cecb: TECB;
  mpac, pac: TPacket;
  ipxspx_drv_entry: array[1..2] of Word;
  SendBuf: TBuf;
  S: string;
  IsFirst, IsSecond: Boolean;

procedure IPXENTR(var par: TIPXRegs); external;
procedure IPXINIT; external;
{$L IPX.OBJ}

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

procedure StrToBuf(const S: string; var B: TBuf);
var
  i: Integer;
begin
  FillChar(B, SizeOf(B), 0);
  for i := 1 to Length(S) do
    B[i - 1] := S[i];
  B[Length(S)] := #0;
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

procedure CheckIPX;
var
  R: Registers;
begin
  R.AX := $7A00;
  Intr($2F, R);
  regis := R;
end;

procedure IPXOpenSocket(es1, di1: Word; Socket: Word);
var
  dx1: Word;
  driver: array[1..2] of Word;
begin
  driver[1] := di1;
  driver[2] := es1;
  asm
    mov bx,00h
    mov al,00h
    mov dx,Socket
    call dword ptr driver
    mov dx1,dx
  end;
  WriteLn('Сокет открыт: ', dx1);
end;

procedure IPXCloseSocket(es1, di1: Word; Socket: Word);
var
  dx1: Word;
  driver: array[1..2] of Word;
begin
  driver[1] := di1;
  driver[2] := es1;
  asm
    mov bx,01h
    mov al,00h
    mov dx,Socket
    call dword ptr driver
    mov dx1,dx
  end;
  WriteLn('Сокет закрыт: ', dx1);
end;

procedure SPXCheckInstallation(es1, di1: Word);
var
  bx1, dx1: Word;
  driver: array[1..2] of Word;
begin
  driver[1] := di1;
  driver[2] := es1;
  asm
    mov bx,10h
    mov al,00h
    call dword ptr driver
    mov bx1,bx
    mov dx1,dx
  end;
  WriteLn('SPX версия: ', bx1);
  WriteLn('SPX доступно каналов: ', dx1);
end;

procedure SPXListenForConnection(es1, di1: Word; Socket: Word);
var
  i: Integer;
  _seg, _ofs: Word;
  driver: array[1..2] of Word;
begin
  driver[1] := di1;
  driver[2] := es1;
  FillChar(cecb, SizeOf(cecb), 0);
  cecb.ESRAddrOfs := 0;
  cecb.ESRAddrSeg := 0;
  cecb.Socket := Socket;
  cecb.FragCnt := 1;
  cecb.Addr1Ofs := Ofs(pac);
  cecb.Addr1Seg := Seg(pac);
  cecb.Size1 := SizeOf(pac);
  _seg := Seg(cecb);
  _ofs := Ofs(cecb);
  pac.PacketType := 5;
  for i := 1 to 4 do
    pac.DestNetwork[i] := 0;
  pac.DestSocket := Socket;
  asm
    mov bx,12h
    mov es,_seg
    mov si,_ofs
    mov al,0
    call dword ptr driver
  end;
end;

procedure SPXListenForSequencedPacket(es1, di1: Word; Socket: Word);
var
  _seg, _ofs: Word;
  driver: array[1..2] of Word;
begin
  driver[1] := di1;
  driver[2] := es1;
  FillChar(mecb, SizeOf(mecb), 0);
  mecb.ESRAddrOfs := 0;
  mecb.ESRAddrSeg := 0;
  mecb.Socket := Socket;
  mecb.FragCnt := 1;
  mecb.Addr1Ofs := Ofs(mpac);
  mecb.Addr1Seg := Seg(mpac);
  mecb.Size1 := SizeOf(mpac);
  _seg := Seg(mecb);
  _ofs := Ofs(mecb);
  asm
    mov bx,17h
    mov es,_seg
    mov si,_ofs
    call dword ptr driver
  end;
end;

begin
  ClrScr;
  WriteLn('Шлюз');
  FillChar(dg, SizeOf(dg), 0);
  FillChar(cn, SizeOf(cn), 0);
  dg.ncb_lana_num := 0;
  cn.ncb_lana_num := 0;
  WriteLn('Инициализация адаптера');
  dg.ncb_command := NCBRESET;
  if NetbiosCmd(dg) <> NRC_GOODRET then
  begin
    WriteLn('Ошибка: ', dg.ncb_cmd_cplt);
    Halt(1);
  end;
  SetName16(dg.ncb_name, 'NetbiosGateaway');
  dg.ncb_command := NCBADDNAME;
  if NetbiosCmd(dg) <> NRC_GOODRET then
  begin
    WriteLn('Ошибка: ', dg.ncb_cmd_cplt);
    Halt(2);
  end;
  SetName16(cn.ncb_name, 'NetbiosGateaway');
  SetName16(cn.ncb_callname, 'NetbiosChannel');
  cn.ncb_command := NCBCALL;
  if NetbiosCmd(cn) <> NRC_GOODRET then
  begin
    WriteLn('Ошибка: ', cn.ncb_cmd_cplt);
    Halt(3);
  end;
  CheckIPX;
  IPXOpenSocket(regis.ES, regis.DI, SPX_SOCKET);
  SPXCheckInstallation(regis.ES, regis.DI);
  SPXListenForConnection(regis.ES, regis.DI, SPX_SOCKET);
  WriteLn('Ожидание подключения SPX');
  while cecb.InUse <> 0 do
  begin
  end;
  WriteLn('Соединение SPX установлено');
  IsFirst := True;
  IsSecond := False;
  repeat
    SPXListenForSequencedPacket(regis.ES, regis.DI, SPX_SOCKET);
    while mecb.InUse <> 0 do
    begin
    end;
    S := mpac.Data;
    WriteLn('Получено: ', S);
    if S = 'exit' then
    begin
      IsFirst := True;
      IsSecond := True;
    end;
    if IsFirst then
    begin
      SetName16(dg.ncb_callname, 'NetbiosDatagram');
      dg.ncb_command := NCBDGSEND;
      StrToBuf(S, SendBuf);
      SetNcbBuf(dg, SendBuf, Length(S) + 1);
      NetbiosCmd(dg);
    end;
    if IsSecond then
    begin
      cn.ncb_command := NCBSEND;
      StrToBuf(S, SendBuf);
      SetNcbBuf(cn, SendBuf, Length(S) + 1);
      NetbiosCmd(cn);
    end;
    IsFirst := not IsFirst;
    IsSecond := not IsSecond;
  until (not IsFirst) and (not IsSecond);
  cn.ncb_command := NCBHANGUP;
  NetbiosCmd(cn);
  dg.ncb_command := NCBDELNAME;
  NetbiosCmd(dg);
  cn.ncb_command := NCBDELNAME;
  NetbiosCmd(cn);
  IPXCloseSocket(regis.ES, regis.DI, SPX_SOCKET);
end.
