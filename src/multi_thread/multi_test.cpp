#pragma GCC optimize(3, "Ofast", "inline")

#include <algorithm>
#include <numeric>

#include "dynamic_bf.h"
#define THREAD_NUM 8
using namespace std;

vector<pair<uint32_t, int>> test_data;
constexpr int MAXN = 1<<27;
ofstream fout;

int read_data(string fname) {
  cout << "Read Data From " << fname << endl;
  std::ifstream inFile(fname);
  if (!inFile) {
    cout << "Open File Failed...\n";
    return 0;
  } else {
    cout << "Read Data Successfully." << endl;
  }
  int cnt = 0;
  uint32_t a, b;
  while (inFile >> a >> b) {
    cnt++;
    // cout << a << "  " << b << endl;
    test_data.push_back(make_pair(a, b));
    if (cnt >= MAXN)
      break;
  }
  printf("Read %d KV Pairs.\n", cnt);
  return cnt;
} 
constexpr int UPDATE_LIMIT = (1<<7) - 1; 
template <uint32_t Var_NUM, uint32_t VL>
void insert_DBF(
    int st, int stride,
    DynamicBloomierFilter<Var_NUM,VL>* DBF,int nn) {
    int counts = 0;
    for (auto idx = st; idx < nn; idx += stride) {
        counts ++;
        if (counts & UPDATE_LIMIT) {
            if (!DBF->insert_pair(test_data[idx].first, test_data[idx].second,0)) {
            cout << "Failed at key " << idx << endl;
             break;
            }
            
        }
        else {
            if (!DBF->insert_pair(test_data[idx].first, test_data[idx].second,counts)) {
                cout << "Failed at key " << idx << endl;
                 break;
                }
                counts = 0;
        }
  }
  /*
   uint8_t flag = 0;
    for (auto idx = st; idx < nn; idx += stride) {
        flag |= (idx * 5 >= nn);
        flag |= (idx * 5 >= nn * 2) << 1; 
        if (!DBF->insert_pair(test_data[idx].first, test_data[idx].second,flag)) {
            cout << "Failed at key " << idx << endl;
        // break;
        }
    }
  */
}

template <uint32_t Var_NUM, uint32_t VL>
void lookup_DBF(
    int st, int stride, int& error_cnt,
    DynamicBloomierFilter<Var_NUM,VL>* DBF,int nn) { 
  for (int cc = 0 ; cc < 100; cc ++) {
    for (auto idx = st; idx < nn; idx += stride) {
        int sum = 0;
        uint32_t vv;
        DBF->queryDP(test_data[idx].first, vv);
        sum += vv;
        if (vv != test_data[idx].second) {
        error_cnt++;
        }
    }
  }
}

template <uint32_t Var_NUM, uint32_t VL>
void test_multi_thread(DynamicBloomierFilter<Var_NUM,VL>* DBF, int nn,int thread_num) {
  
  srand((int)time(0));
  srand(time(0));
  DBF->hash_seed = rand();
    DBF->initial();
  timespec dtime1, dtime2;
  clock_gettime(CLOCK_MONOTONIC, &dtime1);
  vector<thread> threads;
  for (int i = 0; i < thread_num; i++) {
    threads.push_back(thread(insert_DBF<Var_NUM,VL>, i, thread_num, DBF, nn));
  }
  for (auto& t : threads) {
    t.join();
  }
  clock_gettime(CLOCK_MONOTONIC, &dtime2);
  long long delay = (long long)(dtime2.tv_sec - dtime1.tv_sec) * 1000000000LL +
                    (dtime2.tv_nsec - dtime1.tv_nsec);
  double dth = (double)1000.0 * nn / delay;
  printf("Inserted %d KV Pairs. Update Throughput: %.5lf MOPS.\n", nn, dth);
    
  threads.clear();
  DBF->exportDP();
  int error_cnt = 0;
  int sum = 0;
  clock_gettime(CLOCK_MONOTONIC, &dtime1);
  for (int i = 0; i < thread_num; i++) {
    threads.push_back(
        thread(lookup_DBF<Var_NUM,VL>, i, thread_num, std::ref(error_cnt), DBF,nn));
  }
  for (auto& t : threads) {
    t.join();
  }
  clock_gettime(CLOCK_MONOTONIC, &dtime2);
  delay = (long long)(dtime2.tv_sec - dtime1.tv_sec) * 1000000000LL +
          (dtime2.tv_nsec - dtime1.tv_nsec);
  dth = (double)1000.0 * nn * 100 / delay;
  printf("Lookup Throughput: %.5lf MOPS.\n", dth);
  if(!(error_cnt == 0)){
    printf("find error %d\n",error_cnt);
  }
   
     
}

int get_rounds(int lognn, int threads){
    int res = 28 - lognn + threads;
    if (res <= 5) {
        return 5;
    }
    return res;
}
 

int main() {
  // ! make sure the dataset has enough KV pairs
  read_data("./my_data"); 
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(19,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<19) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<19, 1 << j);
        delete DBF; 
    }
   }
   printf("finished :%d\n",19);
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(20,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<20) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<20, 1 << j);
        delete DBF; 
    }
   }
   
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(21,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<21) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<21, 1 << j);
        delete DBF; 
    }
   }
   printf("finished :%d\n",21);
   
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(22,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<22) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<22, 1 << j);
        delete DBF; 
    }
   }
   
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(23,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<23) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<23, 1 << j);
        delete DBF; 
    }
   }
   printf("finished :%d\n",23);
   
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(24,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<24) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<24, 1 << j);
        delete DBF; 
    }
   }
   
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(25,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<25) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<25, 1 << j);
        delete DBF; 
    }
   }
   printf("finished :%d\n",25);
   
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(26,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<26) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<26, 1 << j);
        delete DBF; 
    }
   }
   
   for (int j = 0; j <= 4; j ++){ 
    for (int i = 0 ; i < get_rounds(27,j + 1); i++) {
        
        auto DBF = new DynamicBloomierFilter<(uint32_t)((1<<27) * 1.70 * 3.0) / 3u, 8u>();
        test_multi_thread(DBF, 1<<27, 1 << j);
        delete DBF; 
    }
   }

  
   printf("finished :%d\n",27);
  return 0;
}