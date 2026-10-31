#include <winsock2.h>
#include <string>
#include <conio.h>
#include <locale>

#pragma comment(lib, "NETAPI32.LIB")

using namespace std;

int main()
{
	setlocale(LC_ALL, "Russian");
	printf("Cервер Netbios-каналы\n");

	NCB block;
	ZeroMemory(&block,sizeof(NCB));
	block.ncb_lana_num = 0;

	printf("Инициализация адаптера\n");

	block.ncb_command = NCBRESET;
	if(Netbios(&block) != NRC_GOODRET){
		printf("Ошибка: %x\n",block.ncb_retcode);
		getch();
        return -1;
	}

    memset(block.ncb_name,' ',NCBNAMSZ);
    memset(block.ncb_callname,' ',NCBNAMSZ);

	const char *name = "NetbiosChannel";

	memcpy((char*)block.ncb_name,name,strlen(name));

	printf("Добавление имени\n");

	block.ncb_command = NCBADDGRNAME;
	if(Netbios(&block) != NRC_GOODRET){
		printf("Ошибка: %x\n",block.ncb_retcode);
		getch();
        return -2;
	}

	printf("Ожидание подключения шлюза\n");

	const char *everyone = "*";

	memcpy((char*)block.ncb_callname,everyone,strlen(everyone));

	block.ncb_command = NCBLISTEN;
	if(Netbios(&block) != NRC_GOODRET){
		printf("Ошибка: %x\n",block.ncb_retcode);
		getch();
        return -3;
	}

	printf("Ожидание сообщений\n");

    char s[256];

    block.ncb_command = NCBRECV;
    block.ncb_buffer = (unsigned char*)s;

	while (strcmp((char*)s, "exit") != 0){
        block.ncb_length = 256;
        if(Netbios(&block) != NRC_GOODRET){
			printf("Соединение потеряно\n");
            return -4;
        }
		printf("Получено: %s\n", s);
	};

	block.ncb_command = NCBHANGUP;
	Netbios(&block);

	block.ncb_command = NCBDELNAME;
	Netbios(&block);

	
	return 0;
}
