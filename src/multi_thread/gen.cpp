#include <cstdio>
#include <iostream>
#include <algorithm>
#include <set>
#include <vector>
#include <numeric>
using namespace std;
int gen(int l,int r){
    return 1ll * rand() * rand() % (r - l + 1) + l;
}
int main(int argc,char *argv[]){
    srand(20021031^(size_t)new char);
    int n = atoi(argv[1]);

    vector<int> id(n + 1);
    iota(id.begin(),id.end(),0); 
    for (int i = 1; i <= n; i ++)
        swap(id[i],id[rand()%i]);
    for (int i = 1; i <= n; i++){
        int x = id[i]; 
        printf("%d %d\n",x,gen(1,255));
    }

}