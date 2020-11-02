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
        , lowest_{&Block::MakeAtAddress(aspace_.lowest(), size_)}
        , highest_{lowest_}
    {}

    bool NoOverlappingAndNoHoles() const {
        bool result = !lowest_->HasPrev() && !highest_->HasNext()
                      && ((!lowest_->HasNext() && !highest_->HasPrev())
                          || (lowest_->HasNext() && highest_->HasPrev() && lowest_ != highest_));
        if (!result) {
            return false;
        }
        const Block* prev = nullptr;
        lowest_->ForAll([&prev, &result](const Block& b){
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
        lowest_->ForAll([&result, this](const Block& b){
            return result = (b.NextBlockAddress() <= aspace_.highest());
        });
        return result;
    }

    bool SumOfBlockSizesIsConstant() const {
        return size_ == lowest_->SizeOfAll()
               && size_ == free_size_ + occupied_size_;
    }

    bool MemStructureValid() const {
        return NoOverlappingAndNoHoles() &&
               NoOverruns() &&
               SumOfBlockSizesIsConstant();
    }

    Block& FindSuitableForAllocation(Size sz) {
        // sz is aligned and adjusted by block header size
        Block* blk = nullptr;
        lowest_->ForAll([&blk, sz](Block& b){
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

    std::tuple<Block&, Block&> Split(Block& b, Size sz) {

        assert(MemStructureValid());
        assert(b.Splittable());

        // sz is aligned and adjusted by block header size
        assert(sz > Size{Block::BlockHeaderSize});

        Block* prev = b.HasPrev() ? &b.prev() : nullptr;
        Block* next = b.HasNext() ? &b.next() : nullptr;

        bool set_lowest = (b == *lowest_);
        bool set_highest = (b == *highest_);

        Size old_sz = b;
        Address old_addr = b;

        Block::RemoveBlock(b);
        Block& b1{Block::MakeAtAddress(old_addr, sz)};
        Block& b2{Block::MakeAtAddress(b1.NextBlockAddress(), old_sz - sz)};
        if (prev != nullptr) {
            b1.InsertAbove(*prev);
            b2.InsertAbove(b1);
        } else if (next != nullptr) {
            b2.InsertBelow(*next);
            b1.InsertBelow(b2);
        } else {
            b2.InsertAbove(b1);
        }
        if (set_lowest) { lowest_ = &b1; }
        if (set_highest) { highest_ = &b2; }

        assert(MemStructureValid());

        return {b1, b2};
    }

    Block& Join(Block& b1, Block& b2) {
        assert(b1.Above(b2) || b1.Below(b2));
        assert(MemStructureValid());

        Size sz = b1.GetSize() + b2;

        Block* new_block = nullptr;

        bool set_lowest = false;
        bool set_highest = false;

        if (b1.Above(b2)) {
            set_lowest = b1 == *lowest_;
            set_highest = b2 == *highest_;
            Block::RemoveBlock(b1);
            new_block = &Block::MakeAtAddress(b1, sz);
            new_block->InsertBelow(b2);
            Block::RemoveBlock(b2);
        } else {
            set_lowest = b2 == *lowest_;
            set_highest = b1 == *highest_;
            Block::RemoveBlock(b2);
            new_block = &Block::MakeAtAddress(b2, sz);
            new_block->InsertBelow(b1);
            Block::RemoveBlock(b1);
        }

        if (set_lowest) { lowest_ = new_block; }
        if (set_highest) { highest_ = new_block; }

        assert(MemStructureValid());

        return *new_block;
    }

    void* alloc(size_t sz) {
        const Size hdr_size{Block::BlockHeaderSize};
        const Size size = (hdr_size + Size{sz}).Align();
        Block& block = FindSuitableForAllocation(size);

        free_size_ = free_size_ - size;
        occupied_size_ = occupied_size_ + size;

        if (block.GetSize() > size + hdr_size) {
            auto result = Split(block, size);
            auto& [b1, b2] = result;
            b1.SetOccupied(true);
            return b1.ToUserData();
        } else {
            block.SetOccupied(true);
            return block.ToUserData();
        }
    }

    void free(void* ptr) {
        // check that address is in some block
        Block* blk_ptr = nullptr;
        Address addr = aspace_.address(ptr);
        lowest_->ForAll([&blk_ptr,&addr](Block& b){
            if (b.InBlock(addr)) {
                blk_ptr = &b;
                return false;
            }
            return true;
        });
        assert(blk_ptr != nullptr);

        {   // extra check that ptr is correct
            Block& blk = Block::FromUserData(ptr);
            assert(blk == *blk_ptr);
        }

        // check against double free
        assert(!blk_ptr->IsFree());

        blk_ptr->SetOccupied(false);

        free_size_ = free_size_ + blk_ptr->GetSize();
        occupied_size_ = occupied_size_ - blk_ptr->GetSize();

        if (blk_ptr->HasPrev() && blk_ptr->prev().IsFree()) {
            Block& prev = blk_ptr->prev();
            blk_ptr = &Join(prev, *blk_ptr);
        }
        if (blk_ptr->HasNext() && blk_ptr->next().IsFree()) {
            Block& next = blk_ptr->next();
            Join(*blk_ptr, next);
        }
    }

    size_t MemSize() const { return size_; }
    size_t FreeSize() const { return free_size_; }
    size_t OccupiedSize() const { return occupied_size_; }

    template <typename T>
    Allocator<T> allocator() {
        return {*this};
    }

private:
    const AddrSpace aspace_;
    const Size size_;
    Size free_size_;
    Size occupied_size_;
    Block* lowest_ = nullptr;
    Block* highest_ = nullptr;

    friend std::ostream& operator<<(std::ostream& os, const Memory& mem);
};

std::ostream& operator<<(std::ostream& os, const Memory& mem) {
    std::cout << "=========== MEM DUMP ===========" << std::endl;
    std::cout << "memory total size: " << mem.MemSize() << std::endl;
    std::cout << "memory free size: " << mem.FreeSize() << std::endl;
    std::cout << "memory occupied size: " << mem.OccupiedSize() << std::endl;
    std::cout << "blocks:" << std::endl;
    int idx = 0;
    mem.lowest_->ForAll([&idx](const Block& b){
        std::cout << "  " << std::setw(4) << std::right << std::setfill(' ')
                  << idx++ << ": " << b << std::endl;
        return true;
    });
    std::cout << "--------------------------------" << std::endl;
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
