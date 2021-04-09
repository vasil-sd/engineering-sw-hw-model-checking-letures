#pragma once

#include "memory.h"

#include <vector>

class Gc{
    Memory& memory_;
public:
    Gc(Memory& mem) : memory_{mem} { }

    void RegisterRootObject(void* obj) {
        Block& blk = memory_.GetBlockFromUserData(obj);
        blk.root = true;
    }

    void UnregisterRootObject(void* obj) {
        Block& blk = memory_.GetBlockFromUserData(obj);
        blk.root = false;
    }

    void* LinkToPtr(void* from, void* to) {
        Block& blk_from = memory_.GetBlockFromUserData(from);
        Block& blk_to = memory_.GetBlockFromUserData(to);
        if (blk_from.marked) {
            blk_to.to_be_checked = true;
        }
        return to;
    }

    template<typename From, typename To>
    To* LinkToObj(From* from, To* to) {
        return reinterpret_cast<To*>(LinkToPtr(from, to));
    }

    void GcInit() {
        memory_.ForAllBlocks([&](Block& blk){
            blk.marked = false;
            blk.to_be_checked = blk.root;
            return true;
        });
    }

    bool GcMarkStep() {
        bool result = false;
        memory_.ForAllBlocks([&](Block& blk){
            if(blk.to_be_checked) {
                result = true;
                blk.marked = true;
                blk.to_be_checked = false;
                IterateObjPointers(blk, [&](Block& blk){
                    blk.to_be_checked |= !blk.marked;
                });
                return false;
            }
            return true;
        });
        return result;
    }

    void GcCollect() {
        auto get_occupied_unmarked_block = [&]()->Block*{
            Block* result = nullptr;
            memory_.ForAllBlocks([&](Block& blk){
                if (!blk.IsFree() && !blk.marked) {
                    result = &blk;
                    return false;
                }
                blk.marked = false;
                return true;
            });
            return result;
        };
        Block* blk = nullptr;
        while((blk = get_occupied_unmarked_block()) != nullptr) {
            memory_.free(blk->ToUserData());
        }
    }

    void FullGc() {
        GcInit();
        while(GcMarkStep()) { };
        GcCollect();
    }
private:
    template <typename Handler>
    void IterateObjPointers(const Block& blk, Handler&& handler) {
        void **ptr = reinterpret_cast<void**>(blk.ToUserData());
        size_t sz = blk.GetUserDataSize() / sizeof(void*);
        for (size_t idx = 0; idx < sz; ++idx) {
            if (memory_.IsInAddrSpace(ptr[idx])) {
                const auto address = memory_.aspace_.address(ptr[idx]);
                memory_.ForAllBlocks([&](Block& blk){
                    if (blk.InBlock(address)) {
                        handler(blk);
                    }
                    return true;
                });
            }
        }
    }
};
