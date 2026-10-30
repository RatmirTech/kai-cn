program spx_c;

uses DOS, CRT;

type
  TAddress = array[1..6] of Byte;
  TNetNum = array[1..4] of Byte;
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
  mecb, cecb: TECB;
  address: TAddress;
  mpac, pac: TPacket;
  channelnumb: Word;
  ipxspx_drv_entry: array[1..2] of Word;

procedure IPXENTR(var par: TIPXRegs); external;
procedure IPXINIT; external;
{$L IPX.OBJ}

function HexByte(const S: string): Byte;
var
  i, V: Integer;
  C: Char;
begin
  V := 0;
  for i := 1 to Length(S) do
  begin
    C := UpCase(S[i]);
    if (C >= '0') and (C <= '9') then
      V := V * 16 + Ord(C) - Ord('0')
    else if (C >= 'A') and (C <= 'F') then
      V := V * 16 + Ord(C) - Ord('A') + 10;
  end;
  HexByte := Byte(V);
end;

procedure EnterNet(var Net: TNetNum);
var
  i: Integer;
  S: string;
begin
  for i := 1 to 4 do
  begin
    Write('Сеть[', i, ']: ');
    ReadLn(S);
    Net[i] := HexByte(S);
  end;
end;

procedure EnterNode(var Node: TAddress);
var
  i: Integer;
  S: string;
begin
  for i := 1 to 6 do
  begin
    Write('Узел[', i, ']: ');
    ReadLn(S);
    Node[i] := HexByte(S);
  end;
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

procedure SPXEstablishConnection(es1, di1: Word; DestNet: TNetNum; DestNode: TAddress; DestSocket: Word);
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
  cecb.Socket := $6555;
  cecb.ImmAddr := DestNode;
  cecb.FragCnt := 1;
  cecb.Addr1Ofs := Ofs(pac);
  cecb.Addr1Seg := Seg(pac);
  cecb.Size1 := SizeOf(pac);
  _seg := Seg(cecb);
  _ofs := Ofs(cecb);
  pac.PacketType := 5;
  for i := 1 to 4 do
    pac.DestNetwork[i] := DestNet[i];
  pac.DestNode := DestNode;
  pac.DestSocket := DestSocket;
  asm
    mov bx,11h
    mov es,_seg
    mov si,_ofs
    mov al,0
    call dword ptr driver
  end;
end;

procedure SPXSendSequencedPacket(es1, di1: Word; const Message: string);
var
  i: Integer;
  _seg, _ofs: Word;
  driver: array[1..2] of Word;
begin
  driver[1] := di1;
  driver[2] := es1;
  FillChar(mecb, SizeOf(mecb), 0);
  mecb.ESRAddrOfs := 0;
  mecb.ESRAddrSeg := 0;
  mecb.Socket := $6555;
  mecb.FragCnt := 1;
  mecb.Addr1Ofs := Ofs(mpac);
  mecb.Addr1Seg := Seg(mpac);
  mecb.Size1 := SizeOf(mpac);
  mpac.PacketType := 5;
  for i := 1 to 4 do
    mpac.DestNetwork[i] := pac.DestNetwork[i];
  mpac.DestNode := pac.DestNode;
  mpac.DestSocket := pac.DestSocket;
  mpac.TransportControl := 0;
  mpac.DataStreamType := $FA;
  mpac.Data := Message;
  _seg := Seg(mecb);
  _ofs := Ofs(mecb);
  asm
    mov bx,16h
    mov es,_seg
    mov si,_ofs
    mov dx,channelnumb
    call dword ptr driver
  end;
end;

procedure SPXTerminateConnection(es1, di1: Word);
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
  cecb.Socket := $6555;
  cecb.ImmAddr := pac.DestNode;
  cecb.FragCnt := 1;
  cecb.Addr1Ofs := Ofs(pac);
  cecb.Addr1Seg := Seg(pac);
  cecb.Size1 := SizeOf(pac);
  _seg := Seg(cecb);
  _ofs := Ofs(cecb);
  pac.PacketType := 5;
  for i := 1 to 4 do
    pac.DestNetwork[i] := pac.DestNetwork[i];
  pac.DestNode := pac.DestNode;
  pac.DestSocket := pac.DestSocket;
  pac.DataStreamType := $FF;
  asm
    mov bx,13h
    mov es,_seg
    mov si,_ofs
    mov dx,channelnumb
    call dword ptr driver
  end;
end;

var
  DestNet: TNetNum;
  DestNode: TAddress;
  Msg: string;

begin
  ClrScr;
  WriteLn('Клиент SPX');
  CheckIPX;
  if regis.AL = $FF then
    WriteLn('IPX установлен')
  else
    WriteLn('IPX не установлен');
  IPXOpenSocket(regis.ES, regis.DI, $6555);
  SPXCheckInstallation(regis.ES, regis.DI);
  WriteLn('Введите адрес сети шлюза:');
  EnterNet(DestNet);
  WriteLn('Введите адрес узла шлюза:');
  EnterNode(DestNode);
  SPXEstablishConnection(regis.ES, regis.DI, DestNet, DestNode, $1000);
  while cecb.InUse <> 0 do
  begin
  end;
  if cecb.CCode = $00 then
  begin
    channelnumb := pac.SourceConnID;
    WriteLn('Соединение установлено. Канал: ', channelnumb);
    repeat
      Write('Сообщение: ');
      ReadLn(Msg);
      SPXSendSequencedPacket(regis.ES, regis.DI, Msg);
      while mecb.InUse <> 0 do
      begin
      end;
    until Msg = 'exit';
  end
  else
    WriteLn('Соединение не установлено. Ошибка: ', cecb.CCode);
  SPXTerminateConnection(regis.ES, regis.DI);
  IPXCloseSocket(regis.ES, regis.DI, $6555);
end.
