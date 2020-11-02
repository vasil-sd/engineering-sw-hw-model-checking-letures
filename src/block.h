#pragma once

#include "address.h"
#include "size.h"
#include "double_linked_list.h"

#include <cstdint>
#include <iostream>

#include <new>

class Block : public DlElt<Block> {
public:
    static const size_t BlockHeaderSize;
    using Address = AddrSpace::Address;

    // size should include header size
    Block(const Size& size) : size_{size.Align()} {}

    Address GetAddress() const { return {reinterpret_cast<const void*>(this)}; }
    Size GetSize() const { return size_; };

    operator Address() const { return GetAddress(); }
    operator Size() const { return GetSize(); };

    Address NextBlockAddress() const {
        Address addr = *this;
        Size sz = *this;
        return addr + sz;
    }

    static Block& AtAddress(const Address& addr) {
        return *const_cast<Block*>(reinterpret_cast<const Block*>(addr.addr_));
    }

    static Block& MakeAtAddress(const Address& addr, const Size& sz) {
        return *(new(const_cast<void*>(addr.addr_)) Block{sz});
    }

    static void RemoveBlock(const Block& b) {
        const_cast<Block*>(&b)->~Block();
    }

    void* ToUserData() const {
        return reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(this) + BlockHeaderSize);
    }

    static Block& FromUserData(void *ptr) {
        return *reinterpret_cast<Block*>(reinterpret_cast<uintptr_t>(ptr) - BlockHeaderSize);
    }

    Size SizeOfAll() const {
        Size result{0};
        ForAll([&result](const Block& b){
            result = result + b;
            return true;
        });
        return result;
    }

    bool operator==(const Block& rhs) const {
        return GetAddress() == rhs.GetAddress();
    }

    bool Splittable() const {
        return size_ > Size{BlockHeaderSize*2};
    }

    bool InBlock(const Address& addr) {
        return addr >= GetAddress() && addr < NextBlockAddress();
    }

    bool Above(const Block& b) {
        return HasNext() && next() == b;
    }

    bool Below(const Block& b) {
        return HasPrev() && prev() == b;
    }

    bool IsFree() const { return !occupied_; }

    void SetOccupied(bool oc) {
        occupied_ = oc;
    }

private:
    bool occupied_ = false;
    const Size size_;

    friend std::ostream& operator<<(std::ostream& os, const Block& b);
};

const size_t Block::BlockHeaderSize = align(sizeof(Block));

std::ostream& operator<<(std::ostream& os, const Block& b) {
    os << "Addr: " << b.GetAddress()
       << ", Size: " << b.GetSize()
       << ", " << (b.IsFree() ? "Free" : "Occupied");
}
