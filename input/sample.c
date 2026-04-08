typedef int myint;

enum Color { RED = 1, GREEN = 2, BLUE };

struct Node;
union Data;

static int g = 10;
extern float gf;

int sum(int a, int b) {
    int result = a + b;
    int arr[3] = 6;
    if (result > g) {
        int temp = result * 2;
        result = temp;
    }
    return result;
}

int mainVar;
myint aliased = 42;
int *ptr;
