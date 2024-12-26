#include <stdio.h>

int main(int argc, char *argv[])
{
    printf("we get values:\n");
    for (int i = 0; i < argc; i++) {
        printf("%d. %s\n", i, argv[i]);
    }
    return 0;
}
