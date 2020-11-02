#pragma once

#include "address.h"
#include "size.h"
#include "double_linked_list.h"

#include <cstdint>
#include <iostream>

#include <new>

class Block : public DlElt<Block> {
public:
    static const Size HeaderSize;
    using Address = AddrSpace::Address;

    // size should include header size
    Block(const Size& size) : size_{size.Align()} {}

    Address GetAddress() const { return {reinterpret_cast<const void*>(this)}; }
    Size GetSize() const { return size_; };

    Address NextBlockAddress() const { return GetAddress() + GetSize(); }

    static Block& AtAddress(const Address& addr) {
        assert(not_null(addr));
        return *const_cast<Block*>(reinterpret_cast<const Block*>(addr.addr_));
    }

    static Block& MakeAtAddress(const Address& addr, const Size& sz) {
        assert(not_null(addr));
        assert(sz > HeaderSize);
        return *(new(const_cast<void*>(addr.addr_)) Block{sz});
    }

    void* ToUserData() const {
        return reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(this) + static_cast<size_t>(HeaderSize));
    }

    static Block& FromUserData(void *ptr) {
        return *reinterpret_cast<Block*>(reinterpret_cast<uintptr_t>(ptr) - static_cast<size_t>(HeaderSize));
    }

    bool operator==(const Block& rhs) const { return GetAddress() == rhs.GetAddress(); }

    bool Splittable() const { return size_ > (HeaderSize + HeaderSize); }

    bool InBlock(const Address& addr) { return addr >= GetAddress() && addr < NextBlockAddress(); }

    bool IsFree() const { return !occupied_; }

    void SetOccupied(bool oc) { occupied_ = oc; }

private:
    bool occupied_ = false;
    const Size size_;

    friend std::ostream& operator<<(std::ostream& os, const Block& b);
};

const Size Block::HeaderSize{align(sizeof(Block))};

std::ostream& operator<<(std::ostream& os, const Block& b) {
    os << "Addr: " << b.GetAddress()
       << ", Size: " << b.GetSize()
       << ", " << (b.IsFree() ? "Free" : "Occupied");
    return os;
}
