#include <iostream>
#include <string>
#include <vector>
using namespace std;

int main() {
int len = 4;
vector<int> xs = vector<int>(len);
xs[0] = 1;
xs[1] = 2;
xs[2] = xs[0]+xs[1];
cout << xs[2] << endl;
return 0;
}
