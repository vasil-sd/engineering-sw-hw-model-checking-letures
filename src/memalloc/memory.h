#pragma once

#include "block.h"
#include "address.h"
#include "size.h"

#include <tuple>
#include <memory>
#include <iostream>
#include <ios>
#include <iomanip>

template <typename T>
class Allocator;

class Memory {
public:
    using Address = AddrSpace::Address;

    Memory(void* lowest_addr, void* highest_addr)
        : aspace_{lowest_addr, highest_addr}
        , size_{static_cast<size_t>(reinterpret_cast<uintptr_t>(highest_addr) - reinterpret_cast<uintptr_t>(lowest_addr))}
        , free_size_{size_}
        , occupied_size_{0}
    {
        Block::MakeAtAddress(aspace_.lowest(), size_);
    }

    bool NoOverlappingAndNoHoles() const {
        bool result = true;
        const Block* prev = nullptr;
        ForAllBlocks([&prev, &result](const Block& b){
            if (prev != nullptr) {
                result = (prev->NextBlockAddress() == b.GetAddress());
            } else {
                result = !b.HasPrev();
            }
            prev = &b;
            return result;
        });
        return result;
    }

    bool NoOverruns() const {
        bool result;
        ForAllBlocks([&result, highest_addr=aspace_.highest()](const Block& b){
            return result = (b.NextBlockAddress() <= highest_addr);
        });
        return result;
    }

    bool SumOfBlockSizesIsConstant() const {
        return size_ == SizeOfAllBlocks() && size_ == free_size_ + occupied_size_;
    }

    bool MemStructureValid() const {
        return NoOverlappingAndNoHoles()
               && NoOverruns()
               && SumOfBlockSizesIsConstant();
    }

    Block& FindSuitableForAllocation(Size sz) {
        // sz is aligned and adjusted by block header size
        Block* blk = nullptr;
        ForAllBlocks([&blk, sz](Block& b){
            if (b.IsFree() && b.GetSize() >= sz) {
                if (blk == nullptr || blk->GetSize() > b.GetSize()) {
                    blk = &b;
                }
            }
            return true;
        });
        assert(blk != nullptr);
        // todo: memory error handling
        return *blk;
    }

    Block& Split(Block& b, Size sz) { // split block and return first block of pair

        assert(MemStructureValid());
        assert(b.Splittable());

        // sz is aligned and adjusted by block header size
        assert(sz > Block::HeaderSize);

        Size old_sz = b.GetSize();
        Address old_addr = b.GetAddress();

        b.Replace([&old_sz, &old_addr, &sz] () -> Block& {
            Block& b1{Block::MakeAtAddress(old_addr, sz)};
            Block& b2{Block::MakeAtAddress(b1.NextBlockAddress(), old_sz - sz)};
            b2.InsertAbove(b1);
            return b1;
        });

        assert(MemStructureValid());

        return Block::AtAddress(old_addr);
    }

    Block& Join(Block& b) {
        assert(b.HasNext());
        assert(MemStructureValid());

        Size sz = b.GetSize() + b.Next().GetSize();
        Address addr = b.GetAddress();

        b.ReplaceTill([&addr, sz]()->Block&{ return Block::MakeAtAddress(addr, sz);}, b.Next());

        assert(MemStructureValid());

        return Block::AtAddress(addr);
    }

    void* alloc(size_t sz) {
        const Size size = (Block::HeaderSize + Size{sz}).Align();
        Block& block = FindSuitableForAllocation(size);

        assert(block.IsFree());

        free_size_ = free_size_ - size;
        occupied_size_ = occupied_size_ + size;

        if (block.GetSize() > size + Block::HeaderSize) {
            Block& b = Split(block, size);
            b.SetOccupied(true);
            return b.ToUserData();
        } else {
            block.SetOccupied(true);
            return block.ToUserData();
        }
    }

    void free(void* ptr) {
        // check that address is in some block
        Block* blk_ptr = nullptr;
        Address addr = aspace_.address(ptr);
        ForAllBlocks([&blk_ptr,&addr](Block& b){
            if (b.InBlock(addr)) {
                blk_ptr = &b;
                return false;
            }
            return true;
        });
        assert(blk_ptr != nullptr);

        // extra check that ptr is correct
        Block& blk = Block::FromUserData(ptr);
        assert(blk == *blk_ptr);

        // check against double free
        assert(!blk.IsFree());
        blk.SetOccupied(false);

        free_size_ = free_size_ + blk.GetSize();
        occupied_size_ = occupied_size_ - blk.GetSize();

        if (blk.HasNext() && blk.Next().IsFree()) {
            Join(blk);
        }

        if (blk.HasPrev() && blk.Prev().IsFree()) {
            Join(blk.Prev());
        }
    }

    size_t MemSize() const { return size_; }
    size_t FreeSize() const { return free_size_; }
    size_t OccupiedSize() const { return occupied_size_; }

    template <typename T>
    Allocator<T> allocator() {
        return {*this};
    }

    Block& FirstBlock() const {
        return Block::AtAddress(aspace_.lowest());
    }

    template <typename F>
    void ForAllBlocks(F&& f) const {
        FirstBlock().ForAll(std::move(f));
    }

    Size SizeOfAllBlocks() const {
        Size result{0};
        ForAllBlocks([&result](const Block& b){
            result = result + b.GetSize();
            return true;
        });
        return result;
    }

    bool IsInAddrSpace(void* addr) {
        return aspace_.IsInAddrSpace(addr);
    }

    Block& GetBlockFromUserData(void* user_data_ptr){
        const auto address = aspace_.address(user_data_ptr);
        Block* blk_ptr = nullptr;
        ForAllBlocks([&](Block& blk){
            if (blk.InBlock(address)) {
                blk_ptr = &blk;
                return false;
            }
            return true;
        });
        assert(blk_ptr != nullptr);
        return *blk_ptr;
    }

private:
    const AddrSpace aspace_;
    const Size size_;
    Size free_size_;
    Size occupied_size_;

    friend class Gc;

    friend std::ostream& operator<<(std::ostream& os, const Memory& mem);
};

std::ostream& operator<<(std::ostream& os, const Memory& mem) {
    os << "=========== MEM DUMP ===========" << std::endl;
    os << "memory total size: " << mem.MemSize() << std::endl;
    os << "memory free size: " << mem.FreeSize() << std::endl;
    os << "memory occupied size: " << mem.OccupiedSize() << std::endl;
    os << "blocks:" << std::endl;
    int idx = 0;
    mem.ForAllBlocks([&idx, &os](const Block& b){
        os << "  " << std::setw(4) << std::right << std::setfill(' ')
                   << idx++ << ": " << b << std::endl;
        return true;
    });
    os << "--------------------------------" << std::endl;
    return os;
}

template <typename T>
class Allocator {
    Memory& memory_;
public:
    Allocator(Memory& memory) : memory_{memory} {}

    template <typename U>
    Allocator(const Allocator<U>& a) : memory_{a.memory_} {}

    typedef T value_type;
    typedef size_t size_type;
    typedef T* pointer;
    typedef const T* const_pointer;

    pointer allocate(size_type n) {
        return reinterpret_cast<pointer>(memory_.alloc(n * sizeof(T)));
    }

    void deallocate(pointer p, size_type n) {
        memory_.free(p);
    }

    size_type max_size() { return memory_.FreeSize(); }

    ~Allocator() = default;
};
