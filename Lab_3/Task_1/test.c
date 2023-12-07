#include <stdio.h>

void test_f (int &(arr) [])
{
    printf("%d\n", arr[1]);
}

int main ()
{
    int array [2] = {1, 2};
    test_f(array);

    return 0;
}