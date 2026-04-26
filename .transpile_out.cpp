#include <iostream>
#include <string>
#include <vector>
using namespace std;

static int n = 5;
int main() {
vector<int> a = vector<int>(n);
int i = 0;
while (i < n) {
a[i] = i * 2;
i = i + 1;
}
i = 0;
while (i < n) {
cout << a[i] << endl;
i = i + 1;
}
int x = 10;
if (x > 5) {
cout << x << endl;
}
else {
cout << 0 << endl;
}
return 0;
}
