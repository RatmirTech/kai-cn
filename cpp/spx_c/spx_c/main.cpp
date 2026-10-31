#include <wsipx.h>
#include <winsock2.h>
#include <cstdio>
#include <locale>
#include <iostream>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "NETAPI32.LIB")

#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

void enterAddr(char *netNum, char *nodeNum) {
    printf("Введите адрес сети: ");
    scanf("%hhx.%hhx.%hhx.%hhx", &netNum[0], &netNum[1], &netNum[2], &netNum[3]);

    printf("Введите адрес узла: ");
    scanf("%hhx.%hhx.%hhx.%hhx.%hhx.%hhx", &nodeNum[0], &nodeNum[1], &nodeNum[2], &nodeNum[3], &nodeNum[4], &nodeNum[5]);

	getc(stdin);
}

int main()
{
	setlocale(LC_ALL, "Russian");
    printf("Клиент SPX\n");
	WSADATA wsaData;
	sockaddr_ipx addr;
	printf("Инициализация Winsock\n");
	if (WSAStartup(WINSOCK_VERSION, &wsaData)){
		printf("Ошибка %d\n",WSAGetLastError());
		return -1;
	}

	SOCKET sock = socket(AF_IPX, SOCK_STREAM,  NSPROTO_SPX);
	if(sock == INVALID_SOCKET){
		printf("Ошибка %d\n",WSAGetLastError());
		return -2;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sa_family = AF_IPX;

	enterAddr(addr.sa_netnum, addr.sa_nodenum);

	addr.sa_socket = 0x1000;

	printf("Подключение к щшлюзу\n");

	if(connect(sock, (sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR){
		printf("Ошибка %d\n",WSAGetLastError());
		return -3;
	}

    char s[256];
	memset(s,0,sizeof(s));

	while(strcmp(s,"exit") != 0)
	{
		printf("Введите сообщение: ");
		std::cin.getline(s,256);
		
		if(send(sock,s,strlen(s)+1,0) <= 0){
			printf("Подключение потеряно\n");
			break;
		}
	};

	closesocket(sock);
	WSACleanup();

	return 0;
}
