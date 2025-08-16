#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define WEAPON 34

double balanced[WEAPON];

struct casE{
    char name[WEAPON][WEAPON];
    int price[WEAPON];
    int damage[WEAPON];
    float firerate[WEAPON];
    int magazine[WEAPON];
    int falloff[WEAPON];
    float range[WEAPON];
    float recoil[WEAPON];
};

struct casE ammo;

void gamemenu();
void play(struct casE *ptr);
void about(struct casE *ptr, int count);

int main(){

    gamemenu();

    return 0;
}

void gamemenu(){

    struct casE *ptr = &ammo;

    FILE *fptr;

    fptr = fopen("case.txt","r");

    int i = 0;
    //Extracting weapon data from file
    while (fscanf(fptr, "%s %d %d %f %d %d %f %f", ptr->name[i], &ptr->price[i], &ptr->damage[i],
                &ptr->firerate[i], &ptr->magazine[i], &ptr->falloff[i], &ptr->range[i], &ptr->recoil[i]) != EOF && i < WEAPON) {
        balanced[i] = ((ptr->damage[i] * ptr->firerate[i]) + (ptr->magazine[i] * ptr->range[i])) \
        / (float)(ptr->falloff[i] + ptr->recoil[i]); 
        i++;
    }

    //Balance Score = ((Damage * Fire Rate) + Magazine Size) / Falloff + Recoil

    fclose(fptr);

    int choise;

    do {
        printf("\nMenu");
        printf("\n--------");

        printf("\n 1. Play");
        printf("\n 2. Options");
        printf("\n 3. Help");
        printf("\n 4. About");
        printf("\n 5. Exit");

        printf("\n\nYour Choise : " );
        scanf("%d",&choise);

        switch (choise) {
            case 1:
                play(&ammo);
                break;
            case 2: case 3:
                // Options and Help
                printf("Options and Help not implemented yet.\n");
                break;
            case 4:
                about(&ammo,i);
                break;
            default:
                break;
        }
    } while (choise != 5);
    
}

void about(struct casE *ptr, int count){

    printf("|------------|--------|------|---------------|-------------|--------------|--------------|------|\n");
    printf("|Weapon Name |Price($)|Damage|Fire Rate (RPM)|Magazine Size|Damage Falloff|Accurate Range|Recoil|\n");
    printf("|------------|--------|------|---------------|-------------|--------------|--------------|------|\n");

    //Printing weapon data to the screen
    for (int j = 0; j < count; j++) {
        printf("|%-12s|%8d|%6d|%15.2f|%13d|%14d|%14.2f|%6.1f|\n", ptr->name[j], ptr->price[j], ptr->damage[j],
               ptr->firerate[j], ptr->magazine[j], ptr->falloff[j],ptr->range[j],ptr->recoil[j]);
    }
    printf("|------------|--------|------|---------------|-------------|--------------|--------------|------|\n");

}

void play(struct casE *ptr){

    int chs,j,wp,k,slctw,blnc,randnum,enemy=0,you=0;
    srand(time(NULL));
    
    printf("Welcome the FireSync\n1) T: \n2) CT: \nPlease select your team: ");
    scanf("%d",&chs);
    for (size_t i = 1; i <= 5; i++){
        k = 1;
        switch (i){
            case 1:
                blnc = 900;
                printf("Your Balance (Round %d): $%d\n",i,blnc);
                for (size_t j = 0; j < 10; j++){
                    printf("%d) %s $%d\n",k,ptr->name[j],ptr->price[j]);
                    k++;
                }
                printf("Please Select your weapon: ");
                scanf("%d",&slctw);
                //Prevent possible errors
                while (1 == 1){
                    if (slctw > 10) {
                        printf("An invalid number was entered\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    } else if(blnc < ptr->price[slctw-1]){
                        printf("Your money isn't enough\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    }
                    else {
                        break;
                    }
                }
                blnc -= ptr->price[slctw-1];
                randnum = rand() % 10;
                printf("Your Weapon is %s \nEnemy Weapon is %s",ptr->name[slctw-1],ptr->name[randnum]);
                usleep(1000000);
                //Showing the result of the round and the winner
                if (balanced[slctw-1] > balanced[randnum]){
                    printf("\nYou win\n");
                    you++;
                } else {
                    printf("\nYou lose\n");
                    enemy++;
                }
                printf("Score Table : %d %d\n",you,enemy);
                break;
            case 2: 
                blnc += 1700;
                printf("Your Balance (Round %d): $%d\n",i,blnc);
                for (size_t j = 10; j < 17; j++){
                    printf("%d) %s $%d\n",k,ptr->name[j],ptr->price[j]);
                    k++;
                }
                printf("Please Select your weapon: ");
                scanf("%d",&slctw);
                //Prevent possible errors
                while (1 == 1){
                    if (slctw > 7) {
                        printf("An invalid number was entered\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    } else if(blnc < ptr->price[10+(slctw-1)]){
                        printf("Your money isn't enough\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    }
                    else {
                        break;
                    }
                }
                //Balance reduction
                blnc -= ptr->price[10+(slctw-1)];
                //Weapon selection part of the bot
                randnum = (rand() % 7) + 10;
                printf("Your Weapon is %s \nEnemy Weapon is %s",ptr->name[10+(slctw-1)],ptr->name[randnum]);
                usleep(1000000);
                //Showing the result of the round and the winner
                if (balanced[10+(slctw-1)] > balanced[randnum]){
                    printf("\nYou win\n");
                    you++;
                } else {
                    printf("\nYou lose\n");
                    enemy++;
                }
                printf("Score Table : %d %d\n",you,enemy);
                break;
            case 3:
                blnc += 2000;
                printf("Your Balance (Round %d): $%d\n",i,blnc);
                for (size_t j = 17; j < 23; j++){
                    printf("%d) %s $%d\n",k,ptr->name[j],ptr->price[j]);
                    k++;
                }
                printf("Please Select your weapon: ");
                scanf("%d",&slctw);
                //Prevent possible errors
                while (1 == 1){
                    if (slctw > 6) {
                        printf("An invalid number was entered\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    } else if(blnc < ptr->price[17+(slctw-1)]){
                        printf("Your money isn't enough\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    }
                    else {
                        break;
                    }
                }
                //Balance reduction
                blnc -= ptr->price[17+(slctw-1)];
                //Weapon selection part of the bot
                randnum = (rand() % 6) + 17;
                printf("Your Weapon is %s \nEnemy Weapon is %s",ptr->name[17+(slctw-1)],ptr->name[randnum]);
                usleep(1000000);
                //Showing the result of the round and the winner
                if (balanced[17+(slctw-1)] > balanced[randnum]){
                    printf("\nYou win\n");
                    you++;
                } else {
                    printf("\nYou lose\n");
                    enemy++;
                }
                printf("Score Table : %d %d\n",you,enemy);
                break;
            case 4:
                blnc += 2600;
                printf("Your Balance (Round %d): $%d\n",i,blnc);
                for (size_t j = 23; j < 30; j++){
                    printf("%d) %s $%d\n",k,ptr->name[j],ptr->price[j]);
                    k++;
                }
                printf("Please Select your weapon: ");
                scanf("%d",&slctw);
                //Prevent possible errors
                while (1 == 1){
                    if (slctw > 7) {
                        printf("An invalid number was entered\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    } else if(blnc < ptr->price[23+(slctw-1)]){
                        printf("Your money isn't enough\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    }
                    else {
                        break;
                    }
                }
                //Balance reduction
                blnc -= ptr->price[23+(slctw-1)];
                //Weapon selection part of the bot
                randnum = (rand() % 7) + 23;
                printf("Your Weapon is %s \nEnemy Weapon is %s",ptr->name[23+(slctw-1)],ptr->name[randnum]);
                usleep(1000000);
                //Showing the result of the round and the winner
                if (balanced[23+(slctw-1)] > balanced[randnum]){
                    printf("\nYou win\n");
                    you++;
                } else {
                    printf("\nYou lose\n");
                    enemy++;
                }
                printf("Score Table : %d %d\n",you,enemy);
                break;
            case 5:
                blnc += 3500;
                printf("Your Balance (Round %d): $%d\n",i,blnc);
                for (size_t j = 30; j < 34; j++){
                    printf("%d) %s $%d\n",k,ptr->name[j],ptr->price[j]);
                    k++;
                }
                printf("Please Select your weapon: ");
                scanf("%d",&slctw);
                //Prevent possible errors
                while (1 == 1){
                    if (slctw > 4) {
                        printf("An invalid number was entered\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    } else if(blnc < ptr->price[30+(slctw-1)]){
                        printf("Your money isn't enough\n");
                        printf("Please Select your weapon: ");
                        scanf("%d",&slctw);
                    }
                    else {
                        break;
                    }
                }
                //Balance reduction
                blnc -= ptr->price[30+(slctw-1)];
                //Weapon selection part of the bot
                randnum = (rand() % 4) + 30;
                printf("Your Weapon is %s \nEnemy Weapon is %s",ptr->name[30+(slctw-1)],ptr->name[randnum]);
                usleep(1000000);
                //Showing the result of the round and the winner
                if (balanced[30+(slctw-1)] > balanced[randnum]){
                    printf("\nYou win\n");
                    you++;
                } else {
                    printf("\nYou lose\n");
                    enemy++;
                }
                printf("Score Table : %d %d\n",you,enemy);
                break;
            default:
                break;
        }
    }
}

// Ref
//https://docs.google.com/spreadsheets/d/11tDzUNBq9zIX6_9Rel__fdAUezAQzSnh5AVYzCP060c