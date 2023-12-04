#ifndef DYNAMIC_BLOOMIER_FILTER
#define DYNAMIC_BLOOMIER_FILTER

#pragma GCC optimize(3, "Ofast", "inline")
#include <iostream>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <unordered_map>
#include <vector>
#include <cstring>
#include <cmath>
#include "murmur3.h"
#include <fstream>
#include <algorithm>
#include <map>
#include <cassert>
#include <unordered_map>

#define random(x) rand() % (x)
#define next(x) ((x) + 1 == HASH_NUM ? 0 : (x) + 1)


#define HASH_NUM 3
#define KICK 50000
#define STK 1000000
#define PREDICT_NUM 50

using namespace std;

template <uint32_t Var_NUM, uint32_t VL>
class DynamicBloomierFilter
{
public:
    int level, stk;
    int lk_idx;
    int InsNum;
    const uint32_t Hash_Mask;
    int hash_seed = 0;

    double memory_efficiency = 0.0;
    // bucket struct
    struct bucket
    {
        //The number of the equation(0,1,...M-1)
        int counter = 0; //counter for value stored in this bucket
        uint8_t A;       //The variable in the equation
        int checkCycle;
        uint32_t layer1mem[4];
        uint32_t *layer2mem = 0;

        void insert_mem(uint32_t value)
        {
            if (counter == 4)
            {
                layer2mem = new uint32_t[20];
                layer2mem[0] = value;
            }
            else if (counter > 4)
            {
                layer2mem[counter - 4] = value;
            }
            else
            {
                layer1mem[counter] = value;
            }
            counter++;
        }
        uint32_t query_mem(int index)
        {
            if (index <= 3)
            {
                return layer1mem[index];
            }
            else
            {
                return layer2mem[index - 4];
            }
        }
    } B[Var_NUM];

    
    inline uint32_t multiply_high_u32(uint32_t x, uint32_t y) const {
        return (uint32_t) (((uint64_t) x * (uint64_t) y) >> 32);
    }

    // calculate 3 hash
    inline void calc_mapping_hash(uint32_t key, uint32_t *hash)
    {
        for (int j = 0; j < HASH_NUM; j++)
            hash[j] = multiply_high_u32(MurmurHash3_x86_32(&key, 4, j + hash_seed), Hash_Mask) + j * Hash_Mask;
    }

    // return the estimated cost for adjusting
    double look_ahead(int pos, uint32_t key, int step)
    {
        if (step == 0)
            return B[pos].counter;
        double sum = 1;
        for (int i = 0; i < B[pos].counter; i++)
        {
            int key_i = B[pos].query_mem(i);
            if (key != key_i)
            {
                uint32_t hash[HASH_NUM];
                calc_mapping_hash(key, hash);
                double minval = 1e9;
                for (int j = 0; j < HASH_NUM; j++)
                {
                    int a = hash[j], b = hash[next(j)], c = hash[next(next(j))];
                    if (a != pos && B[a].checkCycle != InsNum)
                    {
                        double ss = look_ahead(a, key_i, step - 1);
                        minval = min(minval, ss);
                    }
                }
                sum += minval;
            }
        }
        return sum;
    }

    // recursive adjust
    bool adjust(uint32_t key, uint32_t *hash, int value, uint32_t delta)
    {
        if (level > KICK || stk > STK)
        {
            return false;
        }
        level++;

        int mo = -1;
        double minoverhead = 1e12;
        double look;
        for (int j = 0; j < HASH_NUM; j++){
            if (B[hash[j]].checkCycle != InsNum){
                mo = j;
            }
        }
        if(mo == -1){
            for(int i = 0; i < 3; i++){
                B[hash[i]].checkCycle = InsNum - 1;
            }
        }
        for (int j = 0; j < HASH_NUM; j++)
        {
            if (memory_efficiency <= 0.2)
            {
                look = look_ahead(hash[j], key, 0);
            }
            else if(memory_efficiency <= 0.4)
            {
                look = look_ahead(hash[j], key, 1);
            }
            else{
                look = look_ahead(hash[j], key, 2);
            }
            // look = look_ahead(hash[j], key, STEP);
            if (B[hash[j]].checkCycle != InsNum && look < minoverhead)
                minoverhead = look,
                mo = j;
        }
        
        // to adjust if value != -1
        if (value != -1)
        {
            uint32_t sum = value, oldA = 0, olddp = 0;
            for (int j = 0; j < HASH_NUM; j++)
            {
                sum = sum ^ B[hash[j]].A;
                // sum -= B[hash[j]].A;
            }
            for (int j = 0; j < HASH_NUM; j++)
            {
                int a = hash[mo], b = hash[next(mo)], c = hash[next(next(mo))];
                if (B[a].checkCycle != InsNum)
                {
                    oldA = B[a].A;
                    // B[a].A = (sum + B[a].A) & 0xff;
                    B[a].A = B[a].A ^ sum;

                    // olddp = B[a].dp;
                    B[a].checkCycle = InsNum;
                    stk += B[a].counter;
                    bool ret = true;
                    for (int i = 0; i < B[a].counter; i++)
                    {
                        int key_i = B[a].query_mem(i);
                        if (key_i == key) 
                        {
                            continue;
                        }
                        uint32_t hash_i[HASH_NUM];
                        calc_mapping_hash(key_i, hash_i);
                        if (adjust(key_i, hash_i, -1, sum) == false)
                        {
                            ret = false;
                            // cout << InsNum << " False" << endl;
                            break;
                        }
                    }
                    // if (B[a].counter == 0)
                    //     B[a].dpadd = 1;
                    if (ret == true)
                    {
                        // B[b].dp++;
                        // B[c].dp++;
                        // B[b].dpadd = B[a].dpadd;
                        // B[c].dpadd = B[a].dpadd;
                        // lk_idx = B[a].counter;
                        // assert(DBFdata[key] == query(key));
                        return true;
                    }
                    stk -= B[a].counter;
                    B[a].checkCycle = InsNum - 1;
                    B[a].A = oldA;
                }
                mo = next(mo);
            }
            // cout << InsNum << " False Case 2" << endl;
            return false;
        }
        // if value == -1, it means we don't know key2value info
        else
        {
            uint32_t oldA = 0, olddp = 0;
            for (int j = 0; j < HASH_NUM; j++)
            {
                int a = hash[mo], b = hash[next(mo)], c = hash[next(next(mo))];
                if (B[a].checkCycle != InsNum)
                {
                    oldA = B[a].A;
                    // B[a].A = (B[a].A - delta) & 0xff;
                    B[a].A = B[a].A ^ delta;
                    
                    
                    // olddp = B[a].dp;
                    B[a].checkCycle = InsNum;
                    stk += B[a].counter;
                    bool ret = true;
                    for (int i = 0; i < B[a].counter; i++)
                    {
                        int key_i = B[a].query_mem(i);
                        if (key_i == key)
                        {
                            continue;
                        }
                        uint32_t hash_i[HASH_NUM];
                        calc_mapping_hash(key_i, hash_i);
                        // if (adjust(key_i, hash_i, -1, -delta) == false)
                        if(adjust(key_i, hash_i, -1, delta) == false)
                        {
                            ret = false;
                            break;
                        }
                    }
                    // if (B[a].counter == 0)
                    //     B[a].dpadd = 1;
                    if (ret == true)
                    {
                        // assert(rightValue == query(key));
                        // B[b].dp++;
                        // B[c].dp++;
                        // B[b].dpadd = B[a].dpadd;
                        // B[c].dpadd = B[a].dpadd;
                        // lk_idx = B[a].counter;
                        return true;
                    }
                    stk -= B[a].counter;
                    B[a].checkCycle = InsNum - 1;
                    B[a].A = oldA;
                }
                mo = next(mo);
            }
            return false;
        }
    }

public:
    /*
     * history for KICK and STK
     * stk is the number of keys hashed to affected buckets and
     * level is the depth of recursion(whenever execute adjust, level++)
     */
    vector<int> kick_his;
    vector<int> stk_his;
    vector<uint8_t> DP;
        
    // constructor
    DynamicBloomierFilter():Hash_Mask((int)Var_NUM / 3), InsNum(0), level(0), stk(0)
    {
        kick_his.clear();
        stk_his.clear();
    }

    DynamicBloomierFilter(uint32_t hash_seed_):hash_seed(hash_seed_), Hash_Mask((int)Var_NUM / 3), InsNum(0), level(0), stk(0)
    {
        kick_his.clear();
        stk_his.clear();
    }

    // destructor
    ~DynamicBloomierFilter()
    {
    }
    
    // simple query
    int query(uint32_t key)
    {
        uint32_t hash[HASH_NUM];
        calc_mapping_hash(key, hash);
        return (B[hash[0]].A ^ B[hash[1]].A ^ B[hash[2]].A);
    }
 
    // query in the Data Plane
    inline void queryDP(uint32_t &key, uint32_t &v)
    {
        uint32_t hash[HASH_NUM];
        uint32_t cur_Mask = 0;
        for (int j = 0; j < HASH_NUM; j++){
            hash[j] = multiply_high_u32(MurmurHash3_x86_32(&key, 4, j + hash_seed) , Hash_Mask) + cur_Mask;
            cur_Mask += Hash_Mask;
        }
            
        v = (DP[hash[0]] ^ DP[hash[1]] ^ DP[hash[2]]);
    }


    // bucket statistics(on number of keys hashed in buckets)
    void print_counter_summary()
    {
        cout << "\nCounter Summary:\n";
        int maxcnt = 0;
        for (int i = 0; i < Var_NUM; i++)
        {
            maxcnt = max(maxcnt, B[i].counter);
        }
        int cnt[2000] = {};
        for (int i = 0; i < Var_NUM; i++)
        {
            cnt[B[i].counter]++;
        }
        for (int i = 0; i <= maxcnt; i++)
        {
            printf("Number of %d counter is %d\n", i, cnt[i]);
        }
        cout << endl;
    }


    // check error with original dataset
    void check_error(vector<pair<uint32_t, int>> &data)
    {
        int falsecnt = 0;
        for (int i = 0; i < InsNum; i++)
        {
            int correct_v = data[i].second;
            if (query(data[i].first) != correct_v)
            {
                falsecnt++;
                // if (falsecnt <= 10)
                //     cout << i << " ";
            }
        }
        if (falsecnt != 0)
            cout <<"Check Error: "<< InsNum << " " << falsecnt << endl;
    }

    // convert a vector to a map<int, int> for counting
    void vector_count(vector<int> &ve)
    {
        int size = ve.size();
        map<int, int> mapCount;
        for (int i = 0; i < size; ++i)
        {
            map<int, int>::iterator iterator(mapCount.find(ve[i]));
            if (iterator != mapCount.end())
            {
                iterator->second++;
            }
            else
            {
                mapCount[ve[i]] = 1;
            }
        }
        int sum = 0;
        for (auto i : mapCount)
        {
            cout << i.first << " " << i.second << endl;
            sum += i.second;
        }
        cout << "SUM: " << sum << endl;
    }

    void exportDP(){
        for(int i = 0; i < Var_NUM; i++){
            DP.push_back(B[i].A);
        }
    }

    // insert a KV pair
    bool insert_pair(uint32_t key, uint32_t value)
    {
        // cout << key <<" " << value << endl;
        InsNum++;
        memory_efficiency = (double) InsNum / Var_NUM;
        uint32_t hash[HASH_NUM];
        calc_mapping_hash(key, hash);

        for (int j = 0; j < HASH_NUM; j++)
        {
            B[hash[j]].insert_mem(key);
        }

        level = 0;
        stk = 0;

        if (adjust(key, hash, value, 0))
        {
            return true;
        }
        else
            return false;
    }
    
    void initial(){
        for(int i = 0; i< Var_NUM; i++){
            B[i].A = 0;
            B[i].counter = 0; //counter for value stored in this bucket
            B[i].checkCycle;
            memset(B[i].layer1mem, 0, sizeof(B[i].layer1mem));
            if(B[i].layer2mem != nullptr){
                delete B[i].layer2mem;
                B[i].layer2mem = nullptr;
            }
        }
    }

    // build with KV dataset
    bool build(vector<pair<uint64_t, uint32_t>> &data, uint32_t size){
        cout << "Build with dataset consisting of " << size << " KV pair(s)." << endl;
        bool success = true;
        
        while(true){
            for(int i = 0; i < size; i++){
                this->insert_pair(data[i].first, data[i].second);
            }

            int errcnt = 0;
            for(int i = 0; i < size; i++){
                auto res = this->query(data[i].first);
                if(res != data[i].second) errcnt++;
            }
            if(errcnt) {
                cout <<"Error occurs: " << errcnt << endl;
                hash_seed += 10;
                initial();
            }
            else {
                break;
            }
        }
        return success;
    }
};

#endif
