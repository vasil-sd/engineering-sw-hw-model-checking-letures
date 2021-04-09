// faster implementation of GC
#pragma once

#include "memory.h"

#include <vector>

class Gc{
    Memory& memory_;
public:
    // unsafe, max N of blocks is limited to preallocated amount of data in vector to_be_checked
    Gc(Memory& mem) : memory_{mem}, to_be_checked{mem.allocator<Block*>()} { to_be_checked.reserve(16); }
    /*
    For safe implementation we need:
    1. update Allocator class: add reallocate method and account blocks flags during reallocation of blocks
    2. on blocks reallocation we need to check presence of their adderesses in to_be_checked vector
       and update these addresses
    */

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
        void *data = to_be_checked.data();
        const auto address = memory_.aspace_.address(data);
        Block* blk = nullptr;
        memory_.ForAllBlocks([&](Block& b){
            if (b.InBlock(address)) {
                blk = &b;
                return false;
            }
            return true;
        });
        assert(blk != nullptr);
        memory_.ForAllBlocks([&](Block& blk){
            blk.marked = false;
            if (blk.root) {
                blk.to_be_checked = true;
                to_be_checked.push_back(&blk);
            }
            return true;
        });
        blk->marked = true;
    }

    bool GcMarkStep() {
        if (to_be_checked.empty()) {
            return false;
        }
        Block* blk = to_be_checked.back();
        to_be_checked.pop_back();

        blk->marked = true;
        blk->to_be_checked = false;
        IterateObjPointers(*blk, [&](Block& blk){
            if (!blk.marked && !blk.to_be_checked) {
                to_be_checked.push_back(&blk);
            }
        });
        return true;
    }

    void GcCollect() {
        to_be_checked.clear();
        memory_.ForAllBlocks([&](Block& blk){
            if (!blk.IsFree() && !blk.marked) {
                to_be_checked.push_back(&blk);
            }
            blk.marked = false;
            return true;
        });

        for(auto *blk : to_be_checked) {
            memory_.free(blk->ToUserData());
        }
    }

    void FullGc() {
        GcInit();
        while(GcMarkStep()) { };
        GcCollect();
    }
private:
    std::vector<Block *, Allocator<Block *>> to_be_checked;

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
