#include <wsipx.h>
#include <winsock2.h>
#include <conio.h>
#include <cstdio>
#include <locale>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "NETAPI32.LIB")

#define _CRT_SECURE_NO_WARNINGS

bool printAddr(SOCKET sock)
{
	sockaddr_ipx addr;
	int sz = sizeof(addr);
	if(getsockname(sock, (sockaddr*)&addr, &sz) == SOCKET_ERROR){
		printf("Ошибка %d\n",WSAGetLastError());
		getch();
		return false;
	}
	printf("Порт: %X\n", addr.sa_socket);
	printf("Сеть: %X.%X.%X.%X\n", (UCHAR)addr.sa_netnum[0], (UCHAR)addr.sa_netnum[1], (UCHAR)addr.sa_netnum[2], (UCHAR)addr.sa_netnum[3]);
	printf("Узел: %X.%X.%X.%X.%X.%X\n", (UCHAR)addr.sa_nodenum[0], (UCHAR)addr.sa_nodenum[1], (UCHAR)addr.sa_nodenum[2], (UCHAR)addr.sa_nodenum[3], (UCHAR)addr.sa_nodenum[4], (UCHAR)addr.sa_nodenum[5]);
	return true;
}

int main()
{
	setlocale(LC_ALL, "Russian");
	printf("Шлюз\n");
	NCB dg_server;
	NCB cn_server;
	ZeroMemory(&dg_server,sizeof(NCB));
	ZeroMemory(&cn_server,sizeof(NCB));

	printf("Инициализация адаптера\n");

	dg_server.ncb_command = NCBRESET;
	if(Netbios(&dg_server) != NRC_GOODRET){
		printf("Ошибка %x\n",dg_server.ncb_retcode);
		getch();
		return -1;
	}

	const char *name = "NetbiosGateaway";

	memset(dg_server.ncb_name,' ',sizeof(dg_server.ncb_name));
	memset(dg_server.ncb_callname,' ',sizeof(dg_server.ncb_callname));
	strcpy((char*)dg_server.ncb_name,name);
	printf("Добавление имени\n");

	dg_server.ncb_command = NCBADDNAME;
	if(Netbios(&dg_server) != NRC_GOODRET){
		printf("Ошибка %x\n",dg_server.ncb_retcode);
		getch();
		return -2;
	}

	memset(cn_server.ncb_name,' ',sizeof(cn_server.ncb_name));
	memset(cn_server.ncb_callname,' ',sizeof(cn_server.ncb_callname));
	strcpy((char*)cn_server.ncb_name,name);

	const char *channel_server = "NetbiosChannel";

	memcpy((char*)cn_server.ncb_callname,channel_server,strlen(channel_server));

	printf("Подключение к серверу\n");

	cn_server.ncb_command = NCBCALL;
	if(Netbios(&cn_server) != NRC_GOODRET){
		printf("Ошибка %x\n",cn_server.ncb_retcode);
		getch();
		return -3;
	}
	WSADATA wsaData;
	printf("Инициализация Winsock\n");
	
	if(WSAStartup(WINSOCK_VERSION,&wsaData) == SOCKET_ERROR){
		printf("Ошибка %d\n",WSAGetLastError());
		getch();
	}

	SOCKET server = socket(AF_IPX, SOCK_STREAM,  NSPROTO_SPX);

	if(server == INVALID_SOCKET){
		printf("Ошибка %d\n",WSAGetLastError());
		getch();
		return -4;
	}

	sockaddr_ipx addr;
	int sz = sizeof(sockaddr_ipx);

	memset(&addr, 0, sz);
	addr.sa_family = AF_IPX;
	addr.sa_socket = 0x1000;

	if(bind(server, (sockaddr*)&addr, sz) == SOCKET_ERROR)
	{
		printf("Ошибка %d\n",WSAGetLastError());
		getch();
		return -5;
	}

	if(!printAddr(server)){
		return -10;
	}

	if(listen(server, 4) == SOCKET_ERROR)
	{
		printf("Ошибка %d\n",WSAGetLastError());
		getch();
		return -6;
	}

	printf("Ожидания подключения\n");

	SOCKET client = accept(server, (sockaddr*)&addr, &sz);
	if(client == INVALID_SOCKET)
	{
		printf("Ошибка %d\n",WSAGetLastError());
		getch();
		return -7;
	}
	printf("Ожидание сообщений\n");
	sz = sizeof(sockaddr_ipx);

	char s[256];
	dg_server.ncb_command = NCBDGSEND;
	dg_server.ncb_buffer = (UCHAR*)s;
	cn_server.ncb_command = NCBSEND;
	cn_server.ncb_buffer = (UCHAR*)s;

	const char *datagramm_server = "NetbiosDatagram";

	memcpy((char*)dg_server.ncb_callname,datagramm_server,strlen(datagramm_server));

	bool isFirst = true;
	bool isSecond = false;

	do {
		int res = recv(client,s,256,0);
		if(res <= 0){
			printf("Соединение с клиентом потеряно\n");
			break;
		}
		printf("Получено: %s\n",s);
		if(strcmp(s, "exit") == 0){
			isFirst = true;
			isSecond = true;
		}
		if(isFirst){
			dg_server.ncb_length = strlen(s)+1;
			Netbios(&dg_server);
		}
		if(isSecond){
			cn_server.ncb_length = strlen(s)+1;
			Netbios(&cn_server);
		}
		isFirst = !isFirst;
		isSecond = !isSecond;
	} while (isFirst || isSecond);

	strcpy(s,"exit");

	//Отправляем сервера exit

	closesocket(client);
	closesocket(server);

	dg_server.ncb_command = NCBDELNAME;
	Netbios(&dg_server);

	cn_server.ncb_command = NCBDELNAME;
	Netbios(&cn_server);

	return 0;
}
